package com.smartclip.smartclipboard

import android.content.Context
import android.content.res.Configuration
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.PopupWindow
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
    private var keyboardBgColorHex = "#FFFFFF" // PLAN 7 P1-5

    // Typing buffer — accumulates characters for trigger detection
    private val typingBuffer = StringBuilder()

    // Phase 4D: Language state
    enum class InputLanguage { EN, VI }
    private var currentLanguage = InputLanguage.EN
    private var telexProcessor: VietnameseTelexProcessor? = null

    // Phase 4C: Native feel state
    private var lastCommittedChar: Char? = null
    private var lastWasSpace = false

    // UI
    private lateinit var keyboardView: SmartKeyboardView
    private lateinit var suggestionStrip: SuggestionStrip
    private var currentEditorInfo: EditorInfo? = null

    // Phase 4C.1: Key preview popup
    private var keyPreviewPopup: PopupWindow? = null
    private var keyPreviewTextView: TextView? = null
    private var emojiTrayView: EmojiTray? = null
    private var isEmojiTrayVisible = false

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

    // Quick toolbar
    private lateinit var toolbar: QuickToolbar

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Quick toolbar (; @ .com)
        toolbar = QuickToolbar(this) { shortcut ->
            onToolbarShortcut(shortcut)
        }
        root.addView(
            toolbar,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        // Suggestion strip
        suggestionStrip = SuggestionStrip(this)
        root.addView(
            suggestionStrip,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        // Keyboard
        keyboardView = SmartKeyboardView(this)
        keyboardView.setOnKeyPressListener(object : SmartKeyboardView.OnKeyPressListener {
            override fun onKeyPress(keyCode: Int) {
                onKeyPressed(keyCode)
            }
        })
        // Phase 4C.1: Key preview popup
        keyboardView.setKeyPreviewListener(object : SmartKeyboardView.KeyPreviewListener {
            override fun onKeyPreview(keyLabel: String, keyRect: android.graphics.Rect) {
                showKeyPreview(keyLabel, keyRect)
            }
            override fun onKeyPreviewDismissed() {
                dismissKeyPreview()
            }
        })
        root.addView(
            keyboardView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        // Phase 4C.4: Emoji tray (hidden by default)
        emojiTrayView = EmojiTray(this) { emoji ->
            val ic = currentInputConnection ?: return@EmojiTray
            ic.commitText(emoji, 1)
        }
        emojiTrayView?.visibility = View.GONE
        root.addView(
            emojiTrayView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        return root
    }

    override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
        super.onStartInput(info, restarting)
        // FIX BUG B: commit any leftover composing region from previous session
        // (in case onFinishInputView didn't fire — process kill, crash, etc.)
        currentInputConnection?.finishComposingText()
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
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
        // FIX BUG B: commit composing region BEFORE resetting internal state,
        // so unfinished Vietnamese word stays in the editor.
        currentInputConnection?.finishComposingText()

        isKeyboardVisible = false
        handler.removeCallbacks(pollRunnable)
        typingBuffer.clear()
        suggestionStrip.clear()
        // Phase 4C.1 + 4C.4 + 4D: Cleanup
        dismissKeyPreview()
        isEmojiTrayVisible = false
        emojiTrayView?.visibility = View.GONE
        telexProcessor?.reset()
    }

    override fun onFinishInput() {
        super.onFinishInput()
        currentEditorInfo = null
    }

    // ================================================================
    // Key handling
    // ================================================================

    private fun onKeyPressed(keyCode: Int) {
        val ic = currentInputConnection ?: return

        // Ignore if password field
        if (isPasswordField()) {
            commitKeyDirectly(ic, keyCode)
            return
        }

        when (keyCode) {
            -1 -> { // Backspace — FIX BUG A: only delete 1 char per tap, NO auto-repeat
                handleBackspace(ic)
                // Removed: auto-repeat mechanism. onKeyPress fires at ACTION_UP so
                // there's no way to distinguish tap vs long-press — enabling
                // auto-repeat on tap causes uncontrolled character deletion.
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
            -6 -> {
                keyboardView.toggleSymbolLayer()
            }            else -> {
                // PLAN 7 P0-1: Route word-boundary punctuation through handleDelimiter()
                // to avoid commitText replacing active Telex composing region.
                val previewCh = keyboardView.getCharForKey(keyCode)
                if (previewCh != null && previewCh.length == 1) {
                    val wordBoundaryChars = setOf(',', '.', '!', '?', ';', ':')
                    if (previewCh[0] in wordBoundaryChars) {
                        handleDelimiter(ic, previewCh[0])
                        return
                    }
                }

                // Regular character
                val ch = keyboardView.getCharForKey(keyCode) ?: return

                // Phase 4D.4: Vietnamese Telex mode
                if (currentLanguage == InputLanguage.VI && ch.length == 1 && ch[0].isLetter()) {
                    // BUG 3 FIX: if there's a selection, delete it before starting
                    // composing — setComposingText does NOT auto-replace selection
                    // like commitText does.
                    val selected = ic.getSelectedText(0)
                    if (!selected.isNullOrEmpty()) {
                        ic.commitText("", 1)
                        typingBuffer.clear()
                    }
                    // Ensure telex processor exists
                    if (telexProcessor == null) {
                        telexProcessor = VietnameseTelexProcessor()
                    } else {
                        telexProcessor!!.reset()   // clean state if we just cleared selection
                    }
                    val composingText = telexProcessor!!.onChar(ch[0])
                    typingBuffer.append(ch)
                    ic.setComposingText(composingText, 1)
                    lastCommittedChar = composingText.lastOrNull()
                    lastWasSpace = false
                    updateSuggestions(typingBuffer.toString())
                    return
                }

                // FIX 5.2: Handle ;; escape
                if (ch == ";" && typingBuffer.isNotEmpty() && typingBuffer.last() == ';') {
                    // ;; → delete previous ; and keep only one ;
                    ic.deleteSurroundingText(1, 0)  // FIX 5.2: Delete previous ;
                    typingBuffer.clear()
                    // Don't commit another ; — the remaining one is already there
                    updateSuggestions("")
                    return
                }

                // Phase 4C.2: Auto-capitalize first letter after sentence end
                var finalChar = ch
                if (ch.length == 1 && ch[0].isLetter() && !keyboardView.isShifted() && shouldAutoCapitalize()) {
                    finalChar = ch.uppercase()
                }

                // Phase 4C.3: Double-space → period
                if (ch == " " && lastWasSpace && !isPasswordField()) {
                    ic.deleteSurroundingText(1, 0)
                    typingBuffer.deleteCharAt(typingBuffer.length - 1)
                    ic.commitText(". ", 1)
                    lastCommittedChar = '.'
                    lastWasSpace = false
                    typingBuffer.clear()
                    updateSuggestions("")
                    return
                }

                // Add to buffer
                typingBuffer.append(ch)


                // Commit the character
                ic.commitText(finalChar.toString(), 1)

                // Track state
                lastCommittedChar = finalChar.firstOrNull()
                lastWasSpace = (ch == " ")

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
        // Phase 4D.4: If Vietnamese Telex is composing, commit the telex word first
        if (currentLanguage == InputLanguage.VI && telexProcessor != null && !telexProcessor!!.isEmpty()) {
            ic.finishComposingText()
            telexProcessor!!.commit()
        }

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

            // Ensure composing is finished before expansion
            ic.finishComposingText()

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
        // BUG 3 FIX: if there's a selection, delete the entire selection first.
        // deleteSurroundingText does NOT handle selection — it always operates
        // around the cursor / start of selection, leaving selected text intact.
        val selected = ic.getSelectedText(0)
        if (!selected.isNullOrEmpty()) {
            ic.commitText("", 1)
            typingBuffer.clear()
            telexProcessor?.reset()
            lastCommittedChar = null
            lastWasSpace = false
            updateSuggestions("")
            return
        }

        // Phase 4D.4: Vietnamese Telex backspace
        if (currentLanguage == InputLanguage.VI && telexProcessor != null && !telexProcessor!!.isEmpty()) {
            val composingText = telexProcessor!!.onBackspace()
            if (typingBuffer.isNotEmpty()) {
                typingBuffer.deleteCharAt(typingBuffer.length - 1)
            }
            if (composingText.isNotEmpty()) {
                ic.setComposingText(composingText, 1)
            } else {
                ic.finishComposingText()
                ic.deleteSurroundingText(1, 0)
            }
            updateSuggestions(typingBuffer.toString())
            lastCommittedChar = null
            return
        }

        if (typingBuffer.isNotEmpty()) {
            typingBuffer.deleteCharAt(typingBuffer.length - 1)
            updateSuggestions(typingBuffer.toString())
        }
        ic.deleteSurroundingText(1, 0)
        lastCommittedChar = null
    }

    private fun commitKeyDirectly(ic: InputConnection, keyCode: Int) {
        val ch = keyboardView.getCharForKey(keyCode) ?: return
        ic.commitText(ch.toString(), 1)
    }

    /**
     * Handle quick toolbar shortcuts: ; @ .com
     */
    private fun onToolbarShortcut(shortcut: String) {
        val ic = currentInputConnection ?: return
        when (shortcut) {
            ";" -> {
                typingBuffer.append(";")
                ic.commitText(";", 1)
                updateSuggestions(typingBuffer.toString())
            }
            "@" -> {
                typingBuffer.append("@")
                ic.commitText("@", 1)
                updateSuggestions(typingBuffer.toString())
            }
            ".com" -> {
                ic.commitText(".com ", 1)
                typingBuffer.clear()
                updateSuggestions("")
            }
            "EMOJI" -> {
                // Phase 4C.4: Toggle emoji tray
                isEmojiTrayVisible = !isEmojiTrayVisible
                emojiTrayView?.visibility = if (isEmojiTrayVisible) View.VISIBLE else View.GONE
            }
            "LANG" -> {
                // Phase 4D.2: Toggle EN/VI
                currentLanguage = if (currentLanguage == InputLanguage.EN) InputLanguage.VI else InputLanguage.EN
                toolbar.setLanguage(if (currentLanguage == InputLanguage.VI) "VI" else "EN")
                telexProcessor?.reset()
                typingBuffer.clear()
                updateSuggestions("")
            }
            "SWITCH_KEYBOARD" -> {
                // HANG MUC 4: Open system input method picker
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showInputMethodPicker()
            }
        }
    }

    // ================================================================
    // Phase 4C.1: Key Preview Popup
    // ================================================================

    private fun showKeyPreview(keyLabel: String, keyRect: android.graphics.Rect) {
        dismissKeyPreview()

        // Create preview TextView
        val tv = TextView(this).apply {
            text = keyLabel
            textSize = 28f
            setTextColor(if (isDarkMode()) android.graphics.Color.WHITE else android.graphics.Color.BLACK)
            setBackgroundColor(if (isDarkMode()) android.graphics.Color.parseColor("#3A3A3C") else android.graphics.Color.WHITE)
            setPadding(24, 16, 24, 16)
            gravity = Gravity.CENTER
            elevation = 8f
        }
        keyPreviewTextView = tv

        // Measure to get proper size
        tv.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        val popupWidth = maxOf(tv.measuredWidth + 32, 64)
        val popupHeight = maxOf(tv.measuredHeight + 24, 48)

        // Create PopupWindow
        val popup = PopupWindow(tv, popupWidth, popupHeight, false)
        keyPreviewPopup = popup

        // Position: centered above the key, clamped to screen bounds
        val loc = IntArray(2)
        keyboardView.getLocationOnScreen(loc)
        val x = (loc[0] + keyRect.centerX() - popupWidth / 2)
            .coerceIn(0, maxOf(0, resources.displayMetrics.widthPixels - popupWidth))
        val y = loc[1] + keyRect.top - popupHeight - 8

        popup.showAtLocation(keyboardView, Gravity.NO_GRAVITY, x, y)
    }

    private fun dismissKeyPreview() {
        keyPreviewPopup?.dismiss()
        keyPreviewPopup = null
        keyPreviewTextView = null
    }

    private fun isDarkMode(): Boolean {
        return (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
    }

    private fun isPasswordField(): Boolean {
        val inputType = currentEditorInfo?.inputType ?: InputType.TYPE_NULL
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
    }

    /**
     * Phase 4C.2: Auto-capitalize after sentence end.
     * Returns true if next letter should be uppercase.
     */
    private fun shouldAutoCapitalize(): Boolean {
        if (typingBuffer.isNotEmpty()) return false
        return when (lastCommittedChar) {
            null, '.', '!', '?', '\n' -> true
            else -> false
        }
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

            // PLAN 7 P1-5: Read keyboard background color
            keyboardBgColorHex = obj.optString("keyboard_bg_color", "#FFFFFF")
            try {
                val bgColor = android.graphics.Color.parseColor(keyboardBgColorHex)
                keyboardView.setKeyboardBackgroundColor(bgColor)
            } catch (_: Exception) {
                keyboardView.setKeyboardBackgroundColor(android.graphics.Color.WHITE)
            }

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

    // FIX 5.1: Update suggestions — pass trigger AND content
    private fun updateSuggestions(prefix: String) {
        if (isPasswordField() || prefix.isEmpty()) {
            suggestionStrip.clear()
            return
        }

        // Filter triggers that start with typed prefix
        val matching = triggerMap.entries
            .filter { it.key.startsWith(prefix) && it.key != prefix }
            .take(5)
            .sortedBy { it.key }

        // FIX 5.1: Pass both trigger key AND content to suggestion strip
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

    // FIX 5.1: Accept Map entries (trigger → content) instead of just keys
    fun setSuggestions(suggestions: List<Map.Entry<String, String>>, typedLength: Int) {
        container.removeAllViews()

        for ((trigger, content) in suggestions) {
            val chip = TextView(context).apply {
                // FIX 5.1: Show trigger as label but commit content on click
                text = trigger
                setPadding(16, 8, 16, 8)
                textSize = 14f
                setTextColor(0xFF1976D2.toInt())
                setBackgroundColor(0x00000000)
                setOnClickListener {
                    // FIX 5.1: Delete trigger text and commit CONTENT, not trigger
                    (context as? SmartClipboardIME)?.let { ime ->
                        val ic = ime.currentInputConnection ?: return@let
                        val charsToDelete = typedLength
                        ic.deleteSurroundingText(charsToDelete, 0)
                        ic.commitText(content, 1)  // FIX: commit content!
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

// ================================================================
// Quick Toolbar — shortcut buttons for ; @ .com
// ================================================================

class QuickToolbar(context: Context, private val onShortcut: (String) -> Unit) : LinearLayout(context) {

    private val langBtn: TextView

    init {
        orientation = HORIZONTAL
        setPadding(4, 2, 4, 2)
        setBackgroundColor(0xFFF0F0F0.toInt())

        // Phase 4D.2: EN/VI toggle
        langBtn = TextView(context).apply {
            text = "EN"
            setPadding(16, 8, 16, 8)
            textSize = 13f
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0xFF1976D2.toInt())
            setOnClickListener { onShortcut("LANG") }
        }
        addView(langBtn)

        val shortcuts: List<Pair<String, String>> = listOf(
            ";" to ";",
            "@" to "@",
            ".com" to ".com",
        )

        for ((label, shortcut) in shortcuts) {
            // Divider before
            val divider = View(context).apply {
                layoutParams = LayoutParams(1, LayoutParams.MATCH_PARENT).apply {
                    setMargins(4, 8, 4, 8)
                }
                setBackgroundColor(0xFFCCCCCC.toInt())
            }
            addView(divider)

            val btn = TextView(context).apply {
                text = label
                setPadding(20, 8, 20, 8)
                textSize = 14f
                setTextColor(0xFF1976D2.toInt())
                setBackgroundColor(0x00000000)
                setOnClickListener { onShortcut(shortcut) }
            }
            addView(btn)
        }

        // Divider before emoji
        val emojiDivider = View(context).apply {
            layoutParams = LayoutParams(1, LayoutParams.MATCH_PARENT).apply {
                setMargins(4, 8, 4, 8)
            }
            setBackgroundColor(0xFFCCCCCC.toInt())
        }
        addView(emojiDivider)

        val emojiBtn = TextView(context).apply {
            text = "😀"
            setPadding(20, 8, 20, 8)
            textSize = 18f
            setBackgroundColor(0x00000000)
            setOnClickListener { onShortcut("EMOJI") }
        }
        addView(emojiBtn)

        // HANG MUC 4: Switch keyboard button
        val switchDivider = View(context).apply {
            layoutParams = LayoutParams(1, LayoutParams.MATCH_PARENT).apply {
                setMargins(4, 8, 4, 8)
            }
            setBackgroundColor(0xFFCCCCCC.toInt())
        }
        addView(switchDivider)

        val switchKeyboardBtn = TextView(context).apply {
            text = "🌐"
            setPadding(20, 8, 20, 8)
            textSize = 18f
            setBackgroundColor(0x00000000)
            setOnClickListener { onShortcut("SWITCH_KEYBOARD") }
        }
        addView(switchKeyboardBtn)
    }

    fun setLanguage(lang: String) {
        langBtn.text = lang
    }
}

// ================================================================
// Emoji Tray — common emojis grid
// ================================================================

class EmojiTray(context: Context, private val onEmoji: (String) -> Unit) : android.widget.GridLayout(context) {

    private val commonEmojis = listOf(
        "😀", "😂", "😍", "🥰", "😎", "🤔", "😅", "😢", "😤", "👍",
        "👎", "❤️", "🔥", "⭐", "🎉", "🎊", "✅", "❌", "💯", "🙏",
        "📱", "💻", "📧", "📎", "📋", "⏰", "📅", "🔑", "💡", "🔔",
        "✈️", "🚗", "🏠", "🌍", "☀️", "🌙", "⭐", "🌈", "🌸", "🍕",
        "☕", "🍺", "🎵", "📷", "🎮", "⚽", "🏀", "🎯", "🏆", "💪",
    )

    init {
        columnCount = 10
        setPadding(8, 4, 8, 4)
        setBackgroundColor(0xFFE8E8E8.toInt())

        for (emoji in commonEmojis) {
            val btn = android.widget.TextView(context).apply {
                text = emoji
                textSize = 22f
                setPadding(8, 8, 8, 8)
                setOnClickListener { onEmoji(emoji) }
                gravity = android.view.Gravity.CENTER
            }
            val params = android.widget.GridLayout.LayoutParams().apply {
                width = 0
                height = android.widget.GridLayout.LayoutParams.WRAP_CONTENT
                columnSpec = android.widget.GridLayout.spec(android.widget.GridLayout.UNDEFINED, 1f)
            }
            addView(btn, params)
        }
    }
}
