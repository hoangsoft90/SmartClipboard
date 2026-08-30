package com.smartclip.smartclipboard

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.content.res.Configuration

/**
 * SmartKeyboardView — QWERTY keyboard rendered programmatically.
 *
 * Layout (LETTERS layer):
 *   Row 1: Q W E R T Y U I O P
 *   Row 2: A S D F G H J K L
 *   Row 3: [Shift] Z X C V B N M [Backspace]
 *   Row 4: [?123] [,] [Space] [.] [Enter]
 *
 * Layout (SYMBOLS layer):
 *   Row 1: 1 2 3 4 5 6 7 8 9 0
 *   Row 2: @ # $ % & * - + ( )
 *   Row 3: ! " ' : ; / ?
 *   Row 4: [ABC] [,] [Space] [.] [Enter]
 *
 * Key codes:
 *   >= 0  → ASCII character
 *   -1    → Backspace
 *   -2    → Space
 *   -3    → Enter
 *   -4    → Tab
 *   -5    → Shift toggle
 *   -6    → Symbol layer toggle
 */
class SmartKeyboardView(context: Context) : View(context) {

    enum class KeyboardLayer { LETTERS, SYMBOLS }

    interface OnKeyPressListener {
        fun onKeyPress(keyCode: Int)
    }

    interface KeyPreviewListener {
        fun onKeyPreview(keyLabel: String, keyRect: Rect)
        fun onKeyPreviewDismissed()
    }

    private var listener: OnKeyPressListener? = null
    private var previewListener: KeyPreviewListener? = null
    private var isShifted = false
    private var currentLayer = KeyboardLayer.LETTERS

    // PLAN 7 P0-2 + PLAN 8 BUG 1: Backspace long-press repeat state
    private var isBackspaceRepeating = false
    private var backspaceHasRepeated = false  // PLAN 8 BUG 1: tracks if Runnable actually fired
    private val touchHandler = Handler(Looper.getMainLooper())
    private val backspaceRepeatRunnable = object : Runnable {
        override fun run() {
            if (isBackspaceRepeating) {
                backspaceHasRepeated = true   // PLAN 8 BUG 1: mark that repeat happened
                listener?.onKeyPress(-1) // Backspace key code
                touchHandler.postDelayed(this, 70) // Repeat interval
            }
        }
    }

    // Key dimensions
    private val keyHeight = 50   // dp — tổng 4 hàng ≈ 230-250dp
    private val keyMargin = 4
    private val keyboardPadding = 6

    // Theme colors
    private val isDarkMode: Boolean
        get() = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    // Paint objects — LETTERS theme
    private val keyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val keyStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#CCCCCC")
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        textSize = 38f
        textAlign = Paint.Align.CENTER
    }
    private val specialKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E0E0E0")
        style = Paint.Style.FILL
    }

    // PLAN 7 P1-5: Custom keyboard background color
    private var customBgColor: Int? = null

    fun setKeyboardBackgroundColor(color: Int) {
        if (customBgColor != color) {
            customBgColor = color
            invalidate()
        }
    }

    private fun isColorDark(color: Int): Boolean {
        val luminance = (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255
        return luminance < 0.5
    }

    // Dark mode overrides
    private val darkKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#3A3A3C")
        style = Paint.Style.FILL
    }
    private val darkKeyStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#555555")
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }
    private val darkTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 38f
        textAlign = Paint.Align.CENTER
    }
    private val darkSpecialKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2C2C2E")
        style = Paint.Style.FILL
    }
    private val darkBackgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1C1C1E")
        style = Paint.Style.FILL
    }

    // Key data
    private data class Key(
        val label: String,
        val keyCode: Int,
        val isSpecial: Boolean = false
    )

    // LETTERS layer
    private val row1 = listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P")
        .map { Key(it, it[0].code) }
    private val row2 = listOf("A", "S", "D", "F", "G", "H", "J", "K", "L")
        .map { Key(it, it[0].code) }
    private val row3Base = listOf("Z", "X", "C", "V", "B", "N", "M")
        .map { Key(it, it[0].code) }
    private val row4 = listOf(
        Key("?123", -6, true),
        Key(",", ','.code),
        Key("", -2),            // Space
        Key(".", '.'.code),
        Key("↵", -3, true)      // Enter
    )

    // SYMBOLS layer
    private val symbolRow1 = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
        .map { Key(it, it[0].code) }
    private val symbolRow2 = listOf("@", "#", "$", "%", "&", "*", "-", "+", "(", ")")
        .map { Key(it, it[0].code) }
    private val symbolRow3 = listOf("!", "\"", "'", ":", ";", "/", "?")
        .map { Key(it, it[0].code) }
    private val symbolRow4 = listOf(
        Key("ABC", -6, true),
        Key(",", ','.code),
        Key("", -2),            // Space
        Key(".", '.'.code),
        Key("↵", -3, true)      // Enter
    )

    // Key rects for touch detection
    private data class KeyRect(val rect: Rect, val key: Key)
    private val keyRects = mutableListOf<KeyRect>()

    // Touch state
    private var pressedKey: KeyRect? = null

    fun setOnKeyPressListener(l: OnKeyPressListener) {
        listener = l
    }

    fun setKeyPreviewListener(l: KeyPreviewListener) {
        previewListener = l
    }

    fun toggleShift() {
        isShifted = !isShifted
        invalidate()
    }

    fun isShifted(): Boolean = isShifted

    fun toggleSymbolLayer() {
        currentLayer = if (currentLayer == KeyboardLayer.LETTERS) KeyboardLayer.SYMBOLS else KeyboardLayer.LETTERS
        isShifted = false
        invalidate()
    }

    fun isSymbolLayer() = currentLayer == KeyboardLayer.SYMBOLS

    fun getCharForKey(keyCode: Int): String? {
        return if (keyCode in 32..126) {
            val ch = keyCode.toChar().lowercaseChar()
            if (isShifted && ch.isLetter()) ch.uppercaseChar().toString() else ch.toString()
        } else null
    }

    /**
     * BUG 1 FIX: Unified label display — returns key with label adjusted
     * for current Shift state. Used by drawRow, drawRowCentered, drawRow3
     * for BOTH canvas drawing AND keyRects (so preview popup also reflects Shift).
     */
    private fun displayLabel(key: Key): Key {
        if (key.isSpecial || key.label.length != 1 || !key.label[0].isLetter()) return key
        val display = if (isShifted) key.label.uppercase() else key.label.lowercase()
        return key.copy(label = display)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val scale = resources.displayMetrics.density
        val mh = (keyHeight * scale).toInt()
        val mm = (keyMargin * scale).toInt()
        val mp = (keyboardPadding * scale).toInt()

        val desiredHeight = mh * 4 + mm * 3 + mp * 2
        val width = MeasureSpec.getSize(widthMeasureSpec)

        setMeasuredDimension(width, desiredHeight)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        keyRects.clear()

        // PLAN 7 P1-5: Draw background — custom color takes priority over system dark mode
        val bgColor = customBgColor
        if (bgColor != null) {
            val bgPaint = Paint().apply { color = bgColor; style = Paint.Style.FILL }
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)
        } else if (isDarkMode) {
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), darkBackgroundPaint)
        }

        val w = width.toFloat()
        val scale = resources.displayMetrics.density
        val mh = (keyHeight * scale).toInt()
        val mm = (keyMargin * scale).toInt()
        val mp = (keyboardPadding * scale).toInt()

        var y = mp.toFloat()

        if (currentLayer == KeyboardLayer.LETTERS) {
            drawRow(canvas, row1, y, w, mp, mm, mh, scale)
            y += mh + mm
            drawRowCentered(canvas, row2, y, w, mp, mm, mh, scale)
            y += mh + mm
            drawRow3(canvas, y, w, mp, mm, mh, scale)
            y += mh + mm
            drawRow4(canvas, y, w, mp, mm, mh, scale)
        } else {
            drawRow(canvas, symbolRow1, y, w, mp, mm, mh, scale)
            y += mh + mm
            drawRow(canvas, symbolRow2, y, w, mp, mm, mh, scale)
            y += mh + mm
            drawSymbolRow3(canvas, y, w, mp, mm, mh, scale)   // BUG 2 FIX: Backspace on symbol row 3
            y += mh + mm
            drawSymbolRow4(canvas, y, w, mp, mm, mh, scale)
        }
    }

    private fun drawRow(
        canvas: Canvas, keys: List<Key>,
        y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val keyWidth = ((totalWidth - 2 * pad - (keys.size - 1) * margin) / keys.size).toInt()
        var x = pad.toFloat()

        for (key in keys) {
            val displayKey = displayLabel(key)   // BUG 1 FIX: use unified helper
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + keyWidth, y.toInt() + height)
            drawKey(canvas, rect, displayKey, scale)
            keyRects.add(KeyRect(rect, displayKey))   // BUG 1 FIX: save displayKey for preview
            x += keyWidth + margin
        }
    }

    private fun drawRowCentered(
        canvas: Canvas, keys: List<Key>,
        y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val keyWidth = ((totalWidth - 2 * pad - (keys.size - 1) * margin) / (keys.size + 1)).toInt()
        var x = pad + keyWidth / 2.toFloat()

        for (key in keys) {
            val displayKey = displayLabel(key)   // BUG 1 FIX: use unified helper
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + keyWidth, y.toInt() + height)
            drawKey(canvas, rect, displayKey, scale)
            keyRects.add(KeyRect(rect, displayKey))   // BUG 1 FIX: save displayKey for preview
            x += keyWidth + margin
        }
    }

    private fun drawRow3(
        canvas: Canvas, y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val shiftKey = Key("⇧", -5, true)
        val backspaceKey = Key("⌫", -1, true)
        val letterWidth = ((totalWidth - 2 * pad - 2 * margin - 2 * (60 * scale)) / 7).toInt()
        val specialWidth = (60 * scale).toInt()

        var x = pad.toFloat()

        // Shift
        val shiftRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, shiftRect, shiftKey, scale)
        keyRects.add(KeyRect(shiftRect, shiftKey))
        x += specialWidth + margin

        // Letters
        for (key in row3Base) {
            val displayKey = displayLabel(key)   // BUG 1 FIX: use unified helper
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + letterWidth, y.toInt() + height)
            drawKey(canvas, rect, displayKey, scale)
            keyRects.add(KeyRect(rect, displayKey))   // BUG 1 FIX: save displayKey for preview
            x += letterWidth + margin
        }

        // Backspace
        val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, bsRect, backspaceKey, scale)
        keyRects.add(KeyRect(bsRect, backspaceKey))
    }

    private fun drawRow4(
        canvas: Canvas, y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val specialWidth = (80 * scale).toInt()
        val spaceWidth = (totalWidth - 2 * pad - 2 * margin - 2 * specialWidth - 2 * margin - 2 * margin).toInt()
        val periodWidth = (50 * scale).toInt()

        var x = pad.toFloat()

        // ?123 (dynamic label)
        val switchKey = row4[0].copy(label = if (currentLayer == KeyboardLayer.LETTERS) "?123" else "ABC")
        val r1 = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, r1, switchKey, scale)
        keyRects.add(KeyRect(r1, switchKey))
        x += specialWidth + margin

        // ,
        val commaRect = Rect(x.toInt(), y.toInt(), x.toInt() + (40 * scale).toInt(), y.toInt() + height)
        drawKey(canvas, commaRect, row4[1], scale)
        keyRects.add(KeyRect(commaRect, row4[1]))
        x += (40 * scale).toInt() + margin

        // Space
        val spaceRect = Rect(x.toInt(), y.toInt(), x.toInt() + spaceWidth, y.toInt() + height)
        drawKey(canvas, spaceRect, row4[2], scale)
        keyRects.add(KeyRect(spaceRect, row4[2]))
        x += spaceWidth + margin

        // .
        val periodRect = Rect(x.toInt(), y.toInt(), x.toInt() + periodWidth, y.toInt() + height)
        drawKey(canvas, periodRect, row4[3], scale)
        keyRects.add(KeyRect(periodRect, row4[3]))
        x += periodWidth + margin

        // Enter
        val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, bsRect, row4[4], scale)
        keyRects.add(KeyRect(bsRect, row4[4]))
    }

    /**
     * BUG 2 FIX: Symbol row 3 with Backspace at right end.
     * Layout: ! " ' : ; / ? [⌫]
     * Backspace uses keyCode -1 — same as LETTERS layer, handled by
     * existing onKeyPressed(-1) in SmartClipboardIME.
     */
    private fun drawSymbolRow3(
        canvas: Canvas, y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val backspaceKey = Key("⌫", -1, true)
        val specialWidth = (60 * scale).toInt()
        val symWidth = ((totalWidth - 2 * pad - margin - specialWidth) / symbolRow3.size).toInt()

        var x = pad.toFloat()
        for (key in symbolRow3) {
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + symWidth, y.toInt() + height)
            drawKey(canvas, rect, key, scale)
            keyRects.add(KeyRect(rect, key))
            x += symWidth + margin
        }

        // Backspace — right end, same row as symbols
        val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, bsRect, backspaceKey, scale)
        keyRects.add(KeyRect(bsRect, backspaceKey))
    }

    private fun drawSymbolRow4(
        canvas: Canvas, y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val specialWidth = (80 * scale).toInt()
        val spaceWidth = (totalWidth - 2 * pad - 2 * margin - 2 * specialWidth - 2 * margin - 2 * margin).toInt()
        val periodWidth = (50 * scale).toInt()

        var x = pad.toFloat()

        // ABC (switch back)
        val r1 = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, r1, symbolRow4[0], scale)
        keyRects.add(KeyRect(r1, symbolRow4[0]))
        x += specialWidth + margin

        // ,
        val commaRect = Rect(x.toInt(), y.toInt(), x.toInt() + (40 * scale).toInt(), y.toInt() + height)
        drawKey(canvas, commaRect, symbolRow4[1], scale)
        keyRects.add(KeyRect(commaRect, symbolRow4[1]))
        x += (40 * scale).toInt() + margin

        // Space
        val spaceRect = Rect(x.toInt(), y.toInt(), x.toInt() + spaceWidth, y.toInt() + height)
        drawKey(canvas, spaceRect, symbolRow4[2], scale)
        keyRects.add(KeyRect(spaceRect, symbolRow4[2]))
        x += spaceWidth + margin

        // .
        val periodRect = Rect(x.toInt(), y.toInt(), x.toInt() + periodWidth, y.toInt() + height)
        drawKey(canvas, periodRect, symbolRow4[3], scale)
        keyRects.add(KeyRect(periodRect, symbolRow4[3]))
        x += periodWidth + margin

        // Enter
        val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, bsRect, symbolRow4[4], scale)
        keyRects.add(KeyRect(bsRect, symbolRow4[4]))
    }

    private fun drawKey(canvas: Canvas, rect: Rect, key: Key, scale: Float) {
        // PLAN 7 P1-5: Use custom bg luminance for paint selection when set
        val useDark = customBgColor?.let { isColorDark(it) } ?: isDarkMode
        val kp = if (useDark) darkKeyPaint else keyPaint
        val ks = if (useDark) darkKeyStrokePaint else keyStrokePaint
        val tp = if (useDark) darkTextPaint else textPaint
        val skp = if (useDark) darkSpecialKeyPaint else specialKeyPaint

        val paint = if (key.isSpecial) skp else kp
        val radius = 8f * scale

        canvas.drawRoundRect(
            rect.left.toFloat(), rect.top.toFloat(),
            rect.right.toFloat(), rect.bottom.toFloat(),
            radius, radius, paint
        )
        canvas.drawRoundRect(
            rect.left.toFloat(), rect.top.toFloat(),
            rect.right.toFloat(), rect.bottom.toFloat(),
            radius, radius, ks
        )

        // Key text
        val textY = rect.centerY() - (tp.descent() + tp.ascent()) / 2
        canvas.drawText(key.label, rect.centerX().toFloat(), textY, tp)

        // Pressed highlight
        if (pressedKey?.rect == rect) {
            val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (isDarkMode) 0x40FFFFFF else 0x30000000
                style = Paint.Style.FILL
            }
            canvas.drawRoundRect(
                rect.left.toFloat(), rect.top.toFloat(),
                rect.right.toFloat(), rect.bottom.toFloat(),
                radius, radius, highlightPaint
            )
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                val key = findKeyAt(event.x.toInt(), event.y.toInt())
                pressedKey = key
                invalidate()
                // Phase 4C.1: Show key preview
                if (key != null && key.key.label.isNotEmpty()) {
                    previewListener?.onKeyPreview(key.key.label, key.rect)
                }
                // PLAN 7 P0-2: Start backspace repeat on long-press
                // PLAN 8 BUG 1 FIX: reset backspaceHasRepeated on each new press
                if (key != null && key.key.keyCode == -1) {
                    isBackspaceRepeating = true
                    backspaceHasRepeated = false   // PLAN 8 BUG 1: reset for new press
                    touchHandler.postDelayed(backspaceRepeatRunnable, 400)
                }
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                // PLAN 7 P0-2: If finger moved off the Backspace key while pressing,
                // stop the repeat immediately — don't wait for ACTION_UP.
                if (isBackspaceRepeating) {
                    val stillOnBackspace = pressedKey?.rect?.contains(
                        event.x.toInt(), event.y.toInt()
                    ) == true
                    if (!stillOnBackspace) {
                        isBackspaceRepeating = false
                        touchHandler.removeCallbacks(backspaceRepeatRunnable)
                        pressedKey = null
                        invalidate()
                        previewListener?.onKeyPreviewDismissed()
                    }
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                val key = findKeyAt(event.x.toInt(), event.y.toInt())
                val wasRepeating = isBackspaceRepeating  // PLAN 8 BUG 1: save BEFORE reset

                // PLAN 8 BUG 1 FIX: stop repeat + cleanup on finger lift
                isBackspaceRepeating = false
                touchHandler.removeCallbacks(backspaceRepeatRunnable)

                pressedKey = null
                invalidate()
                previewListener?.onKeyPreviewDismissed()

                if (key != null) {
                    try {
                        performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
                    } catch (_: Exception) {}

                    // PLAN 8 BUG 1 FIX: if repeat already fired at least once,
                    // don't fire extra onKeyPress on UP — avoid deleting extra char.
                    if (!(key.key.keyCode == -1 && backspaceHasRepeated)) {
                        listener?.onKeyPress(key.key.keyCode)
                    }
                }
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                isBackspaceRepeating = false
                touchHandler.removeCallbacks(backspaceRepeatRunnable)
                pressedKey = null
                invalidate()
                previewListener?.onKeyPreviewDismissed()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    // PLAN 7 P0-3: Cleanup Handler when view is detached (prevents leak)
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        isBackspaceRepeating = false
        touchHandler.removeCallbacks(backspaceRepeatRunnable)
    }

    private fun findKeyAt(x: Int, y: Int): KeyRect? {
        for (kr in keyRects) {
            if (kr.rect.contains(x, y)) return kr
        }
        return null
    }
}
