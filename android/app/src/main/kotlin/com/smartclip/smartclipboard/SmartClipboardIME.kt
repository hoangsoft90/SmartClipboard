package com.smartclip.smartclipboard

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.inputmethodservice.Keyboard
import android.inputmethodservice.KeyboardView
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.io.File

/**
 * SmartClipboardIME — Phase 1 Technical Prototype.
 *
 * Minimal InputMethodService that:
 * 1. Loads trigger→content cache from snippets_cache.json (written by Flutter app)
 * 2. Detects trigger + delimiter pattern in real-time
 * 3. Replaces trigger text with snippet content
 * 4. Handles ;; escape (outputs single ;)
 * 5. Shows suggestion strip with matching triggers
 * 6. Polls cache_version every 3s when visible (technical debt — see spec 1.3)
 *
 * STRICT RULE 6: This runs in a SEPARATE OS process from Flutter app.
 *   - No shared memory, no static objects across processes
 *   - Sync ONLY via file (snippets_cache.json + cache_version in app_meta table)
 *   - We read cache file directly from app's files directory
 *
 * STRICT RULE 12: IME NEVER queries SQLite — only reads in-memory HashMap
 *   built from cache file. Trigger lookup = O(1).
 */
class SmartClipboardIME : InputMethodService() {

    companion object {
        private const val TAG = "SmartClipboardIME"
        private const val CACHE_FILE_NAME = "snippets_cache.json"
        private const val POLL_INTERVAL_MS = 3000L
    }

    // In-memory trigger map: trigger_text → content
    private var triggerMap = mutableMapOf<String, String>()
    private var lastCacheVersion = 0L

    // Typing buffer — accumulates characters for trigger detection
    private val typingBuffer = StringBuilder()

    // UI
    private lateinit var keyboardView: SmartKeyboardView
    private lateinit var suggestionStrip: SuggestionStrip
    private var inputConnection: InputConnection? = null
    private var currentEditorInfo: EditorInfo? = null

    // Polling
    private val handler = Handler(Looper.getMainLooper())
    private val pollRunnable = object : Runnable {
        override fun run() {
            if (isKeyboardVisible) {
                reloadCacheIfChanged()
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }
    private var isKeyboardVisible = false

    // ================================================================
    // Lifecycle
    // ================================================================

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Suggestion strip
        suggestionStrip = SuggestionStrip(this)
        root.addView(suggestionStrip)

        // Keyboard
        keyboardView = SmartKeyboardView(this)
        keyboardView.setOnKeyPressListener(object : SmartKeyboardView.OnKeyPressListener {
            override fun onKeyPress(keyCode: Int) {
                onKeyPressed(keyCode)
            }
        })
        root.addView(keyboardView)

        return root
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        inputConnection = currentInputConnection
        currentEditorInfo = info
        typingBuffer.clear()
        isKeyboardVisible = true

        // Load cache on start
        loadCache()

        // Start polling for cache updates
        handler.removeCallbacks(pollRunnable)
        handler.postDelayed(pollRunnable, POLL_INTERVAL_MS)

        // Update suggestion strip
        updateSuggestions("")
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        isKeyboardVisible = false
        handler.removeCallbacks(pollRunnable)
        typingBuffer.clear()
        suggestionStrip.clear()
    }

    override fun onFinishInput() {
        super.onFinishInput()
        inputConnection = null
        currentEditorInfo = null
    }

    // ================================================================
    // Key handling
    // ================================================================

    private fun onKeyPressed(keyCode: Int) {
        val ic = inputConnection ?: return

        // Ignore if password field
        if (isPasswordField()) {
            commitKeyDirectly(ic, keyCode)
            return
        }

        when (keyCode) {
            -1 -> { // Backspace
                handleBackspace(ic)
            }
            -2 -> { // Space
                handleDelimiter(ic, ' ')
            }
            -3 -> { // Enter
                handleDelimiter(ic, '\n')
            }
            -4 -> { // Tab
                handleDelimiter(ic, '\t')
            }
            -5 -> { // Shift (toggle)
                keyboardView.toggleShift()
            }
            else -> {
                // Regular character
                val ch = keyboardView.getCharForKey(keyCode) ?: return

                // Handle ;; escape
                if (ch == ";" && typingBuffer.isNotEmpty() && typingBuffer.last() == ';') {
                    // ;; → output single ;, clear buffer
                    typingBuffer.clear()
                    ic.commitText(";", 1)
                    updateSuggestions("")
                    return
                }

                // Add to buffer
                typingBuffer.append(ch)

                // Commit the character
                ic.commitText(ch.toString(), 1)

                // Update suggestions
                updateSuggestions(typingBuffer.toString())
            }
        }
    }

    /**
     * Handle delimiter (Space, Enter, Tab, punctuation).
     * Check if typing buffer contains a trigger — if so, replace.
     */
    private fun handleDelimiter(ic: InputConnection, delimiter: Char) {
        if (typingBuffer.isEmpty()) {
            // Nothing to check — just commit delimiter
            ic.commitText(delimiter.toString(), 1)
            return
        }

        // Check for trigger match
        val bufferStr = typingBuffer.toString()
        val content = triggerMap[bufferStr]

        if (content != null) {
            // Trigger matched! Delete the trigger text and insert content.
            val charsToDelete = bufferStr.length

            // Delete trigger text and insert snippet content
            ic.deleteSurroundingText(charsToDelete, 0)
            ic.commitText(content, 1)
            ic.commitText(delimiter.toString(), 1)
        } else {
            // No trigger match — just commit the delimiter
            ic.commitText(delimiter.toString(), 1)
        }

        // Clear buffer
        typingBuffer.clear()
        updateSuggestions("")
    }

    private fun handleBackspace(ic: InputConnection) {
        if (typingBuffer.isNotEmpty()) {
            typingBuffer.deleteCharAt(typingBuffer.length - 1)
            updateSuggestions(typingBuffer.toString())
        }
        ic.deleteSurroundingText(1, 0)
    }

    private fun commitKeyDirectly(ic: InputConnection, keyCode: Int) {
        val ch = keyboardView.getCharForKey(keyCode) ?: return
        ic.commitText(ch.toString(), 1)
    }

    private fun isPasswordField(): Boolean {
        val inputType = currentEditorInfo?.inputType ?: InputType.TYPE_NULL
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
    }

    // ================================================================
    // Cache management
    // ================================================================

    private fun loadCache() {
        try {
            val cacheFile = getCacheFile() ?: return
            if (!cacheFile.exists()) {
                triggerMap.clear()
                return
            }

            val json = cacheFile.readText()
            val obj = JSONObject(json)

            lastCacheVersion = obj.optLong("cache_version", 0)

            val triggers = obj.optJSONObject("triggers") ?: JSONObject()
            triggerMap.clear()
            val keys = triggers.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                triggerMap[key] = triggers.getString(key)
            }
        } catch (e: Exception) {
            // Fallback: empty state, never crash (spec 1.3)
            triggerMap.clear()
        }
    }

    private fun reloadCacheIfChanged() {
        try {
            val cacheFile = getCacheFile() ?: return
            if (!cacheFile.exists()) return

            // Quick check: read just the cache_version from file
            val json = cacheFile.readText()
            val obj = JSONObject(json)
            val newVersion = obj.optLong("cache_version", 0)

            if (newVersion != lastCacheVersion) {
                // Cache changed — reload full map
                loadCache()
            }
        } catch (_: Exception) {
            // Ignore parse errors — keep old cache
        }
    }

    private fun getCacheFile(): File? {
        // Read from app's files directory (same package as Flutter app)
        return try {
            File(filesDir, CACHE_FILE_NAME)
        } catch (_: Exception) {
            null
        }
    }

    // ================================================================
    // Suggestion strip
    // ================================================================

    private fun updateSuggestions(prefix: String) {
        if (isPasswordField() || prefix.isEmpty()) {
            suggestionStrip.clear()
            return
        }

        val matching = triggerMap.keys
            .filter { it.startsWith(prefix) && it != prefix }
            .take(5)
            .sorted()

        suggestionStrip.setSuggestions(matching, prefix.length)
    }

}

// ================================================================
// Suggestion Strip — horizontal bar showing matching triggers
// ================================================================

class SuggestionStrip(context: Context) : LinearLayout(context) {

    private val container: LinearLayout

    init {
        orientation = HORIZONTAL
        setPadding(8, 4, 8, 4)
        setBackgroundColor(0xFFE8E8E8.toInt())

        container = LinearLayout(context).apply {
            orientation = HORIZONTAL
        }
        addView(container, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
    }

    fun setSuggestions(suggestions: List<String>, typedLength: Int) {
        container.removeAllViews()

        for (trigger in suggestions) {
            val chip = TextView(context).apply {
                text = trigger
                setPadding(16, 8, 16, 8)
                textSize = 14f
                setTextColor(0xFF1976D2.toInt())
                setBackgroundColor(0x00000000)
                setOnClickListener {
                    // Callback to parent IME to insert this suggestion
                    (context as? SmartClipboardIME)?.let { ime ->
                        val ic = ime.currentInputConnection ?: return@let
                        val charsToDelete = typedLength
                        ic.deleteSurroundingText(charsToDelete, 0)
                        ic.commitText(trigger, 1)
                    }
                }
            }
            container.addView(chip)

            // Divider
            val divider = View(context).apply {
                layoutParams = LayoutParams(1, LayoutParams.MATCH_PARENT).apply {
                    setMargins(4, 8, 4, 8)
                }
                setBackgroundColor(0xFFCCCCCC.toInt())
            }
            container.addView(divider)
        }
    }

    fun clear() {
        container.removeAllViews()
    }
}
