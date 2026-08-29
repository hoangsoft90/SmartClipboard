package com.smartclip.smartclipboard

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.view.MotionEvent
import android.view.View

/**
 * SmartKeyboardView — minimal QWERTY keyboard rendered programmatically.
 *
 * Layout:
 *   Row 1: Q W E R T Y U I O P
 *   Row 2: A S D F G H J K L
 *   Row 3: [Shift] Z X C V B N M [Backspace]
 *   Row 4: [?123] [Space] [.] [Enter]
 *
 * Key codes:
 *   >= 0  → ASCII character
 *   -1    → Backspace
 *   -2    → Space
 *   -3    → Enter
 *   -4    → Tab
 *   -5    → Shift toggle
 *   -6    → Symbol layer toggle
 *   -7    → Period
 */
class SmartKeyboardView(context: Context) : View(context) {

    interface OnKeyPressListener {
        fun onKeyPress(keyCode: Int)
    }

    private var listener: OnKeyPressListener? = null
    private var isShifted = false

    // Key dimensions
    private val keyHeight = 50   // dp — tổng 4 hàng ≈ 50*4 + margin/padding ≈ 230-250dp
    private val keyMargin = 4
    private val keyboardPadding = 6

    // Paint objects
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
        textSize = 38f   // giảm từ 48f cho tương xứng với keyHeight=50
        textAlign = Paint.Align.CENTER
    }
    private val specialKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E0E0E0")
        style = Paint.Style.FILL
    }
    private val spaceKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }

    // Key data
    private data class Key(
        val label: String,
        val keyCode: Int,
        val isSpecial: Boolean = false
    )

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
        Key("↵", -3, true)      // ✅ Enter thay cho Backspace trùng
    )

    // Key rects for touch detection
    private data class KeyRect(val rect: Rect, val key: Key)
    private val keyRects = mutableListOf<KeyRect>()

    // Touch state
    private var pressedKey: KeyRect? = null

    fun setOnKeyPressListener(l: OnKeyPressListener) {
        listener = l
    }

    fun toggleShift() {
        isShifted = !isShifted
        invalidate()
    }

    fun getCharForKey(keyCode: Int): String? {
        return if (keyCode in 32..126) {
            val ch = keyCode.toChar().lowercaseChar()   // ✅ luôn chuẩn hoá về thường trước
            if (isShifted && ch.isLetter()) ch.uppercaseChar().toString() else ch.toString()
        } else null
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val scale = resources.displayMetrics.density
        val mh = (keyHeight * scale).toInt()
        val mm = (keyMargin * scale).toInt()
        val mp = (keyboardPadding * scale).toInt()

        // 4 hàng phím + 3 khoảng margin giữa hàng + padding trên/dưới
        val desiredHeight = mh * 4 + mm * 3 + mp * 2
        val width = MeasureSpec.getSize(widthMeasureSpec)

        setMeasuredDimension(width, desiredHeight)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        keyRects.clear()

        val w = width.toFloat()
        val scale = resources.displayMetrics.density
        val mh = (keyHeight * scale).toInt()
        val mm = (keyMargin * scale).toInt()
        val mp = (keyboardPadding * scale).toInt()

        var y = mp.toFloat()

        // Row 1: QWERTYUIOP (10 keys)
        drawRow(canvas, row1, y, w, mp, mm, mh, scale)
        y += mh + mm

        // Row 2: ASDFGHJKL (9 keys, centered)
        drawRowCentered(canvas, row2, y, w, mp, mm, mh, scale)
        y += mh + mm

        // Row 3: [Shift] + ZXCVBNM + [Backspace]
        drawRow3(canvas, y, w, mp, mm, mh, scale)
        y += mh + mm

        // Row 4: [?123] [,] [Space] [.] [⌫]
        drawRow4(canvas, y, w, mp, mm, mh, scale)
    }

    private fun drawRow(
        canvas: Canvas, keys: List<Key>,
        y: Float, totalWidth: Float,
        pad: Int, margin: Int, height: Int, scale: Float
    ) {
        val keyWidth = ((totalWidth - 2 * pad - (keys.size - 1) * margin) / keys.size).toInt()
        var x = pad.toFloat()

        for (key in keys) {
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + keyWidth, y.toInt() + height)
            drawKey(canvas, rect, key, scale)
            keyRects.add(KeyRect(rect, key))
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
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + keyWidth, y.toInt() + height)
            drawKey(canvas, rect, key, scale)
            keyRects.add(KeyRect(rect, key))
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
            val ch = if (isShifted) key.label.uppercase() else key.label
            val displayKey = key.copy(label = ch)
            val rect = Rect(x.toInt(), y.toInt(), x.toInt() + letterWidth, y.toInt() + height)
            drawKey(canvas, rect, displayKey, scale)
            keyRects.add(KeyRect(rect, key))  // Use original key for keyCode
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

        // ?123
        val r1 = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, r1, row4[0], scale)
        keyRects.add(KeyRect(r1, row4[0]))
        x += specialWidth + margin

        // ,
        val r2 = Rect(x.toInt(), y.toInt(), x.toInt() + margin, y.toInt() + height)
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

        // Backspace
        val bsRect = Rect(x.toInt(), y.toInt(), x.toInt() + specialWidth, y.toInt() + height)
        drawKey(canvas, bsRect, row4[4], scale)
        keyRects.add(KeyRect(bsRect, row4[4]))
    }

    private fun drawKey(canvas: Canvas, rect: Rect, key: Key, scale: Float) {
        val paint = if (key.isSpecial) specialKeyPaint else keyPaint
        val radius = 8f * scale

        canvas.drawRoundRect(
            rect.left.toFloat(), rect.top.toFloat(),
            rect.right.toFloat(), rect.bottom.toFloat(),
            radius, radius, paint
        )
        canvas.drawRoundRect(
            rect.left.toFloat(), rect.top.toFloat(),
            rect.right.toFloat(), rect.bottom.toFloat(),
            radius, radius, keyStrokePaint
        )

        // Key text
        val textY = rect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2
        canvas.drawText(key.label, rect.centerX().toFloat(), textY, textPaint)

        // Pressed highlight
        if (pressedKey?.rect == rect) {
            val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0x30000000
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
                return true
            }
            MotionEvent.ACTION_UP -> {
                val key = findKeyAt(event.x.toInt(), event.y.toInt())
                pressedKey = null
                invalidate()

                if (key != null) {
                    // Visual feedback: vibrate briefly
                    try {
                        performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
                    } catch (_: Exception) {}

                    listener?.onKeyPress(key.key.keyCode)
                }
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                pressedKey = null
                invalidate()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun findKeyAt(x: Int, y: Int): KeyRect? {
        for (kr in keyRects) {
            if (kr.rect.contains(x, y)) return kr
        }
        return null
    }
}
