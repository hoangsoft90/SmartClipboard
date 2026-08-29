package com.smartclip.smartclipboard

/**
 * VietnameseTelexProcessor — Telex input engine for Vietnamese.
 *
 * Architecture: THREE parallel lists:
 *   1. originalInput: raw chars as typed (NEVER modified) — for triple/pair detection
 *   2. composedChars: composed output chars (modified by pair/triple/tone)
 *   3. composedBuffer: String view of composedChars (rebuilt on each change)
 *
 * This allows looking back at original raw input for triple detection
 * ("uow" → "ươ") even after partial composition.
 *
 * Telex mapping:
 *   Vowels: aa→â, ee→ê, oo→ô, aw→ă, ow→ơ, uw→ư
 *   Complex: uow→ươ
 *   dd→đ
 *   Tones: s→sac, f→huyen, r→hoi, x→nga, j→nang
 */
class VietnameseTelexProcessor {

    // Original raw input — NEVER modified, used for pair/triple detection
    private val originalInput = mutableListOf<Char>()

    // Composed output chars — modified by pair/triple/tone processing
    private val composedChars = mutableListOf<Char>()

    // String view of composedChars (rebuilt on each change)
    private val composedBuffer = StringBuilder()

    // Vowel pair mapping: 2 raw chars → composed
    private val vowelPairs = mapOf(
        "aa" to "â", "ee" to "ê", "oo" to "ô",
        "aw" to "ă", "ow" to "ơ", "uw" to "ư",
        "uo" to "ư", "oe" to "ơ",
    )

    // Vowel triple mapping: 3 raw chars → composed
    private val vowelTriples = mapOf(
        "uow" to "ươ",
    )

    // Tone marks
    private val toneMap = mapOf(
        's' to mapOf('a' to 'á', 'ă' to 'ắ', 'â' to 'ấ', 'e' to 'é', 'ê' to 'ế', 'i' to 'í', 'o' to 'ó', 'ô' to 'ố', 'ơ' to 'ớ', 'u' to 'ú', 'ư' to 'ứ', 'y' to 'ý'),
        'f' to mapOf('a' to 'à', 'ă' to 'ằ', 'â' to 'ầ', 'e' to 'è', 'ê' to 'ề', 'i' to 'ì', 'o' to 'ò', 'ô' to 'ồ', 'ơ' to 'ờ', 'u' to 'ù', 'ư' to 'ừ', 'y' to 'ỳ'),
        'r' to mapOf('a' to 'ả', 'ă' to 'ẳ', 'â' to 'ẩ', 'e' to 'ẻ', 'ê' to 'ể', 'i' to 'ỉ', 'o' to 'ỏ', 'ô' to 'ổ', 'ơ' to 'ở', 'u' to 'ủ', 'ư' to 'ử', 'y' to 'ỷ'),
        'x' to mapOf('a' to 'ã', 'ă' to 'ẵ', 'â' to 'ẫ', 'e' to 'ẽ', 'ê' to 'ễ', 'i' to 'ĩ', 'o' to 'õ', 'ô' to 'ỗ', 'ơ' to 'ỡ', 'u' to 'ũ', 'ư' to 'ữ', 'y' to 'ỹ'),
        'j' to mapOf('a' to 'ạ', 'ă' to 'ặ', 'â' to 'ậ', 'e' to 'ẹ', 'ê' to 'ệ', 'i' to 'ị', 'o' to 'ọ', 'ô' to 'ộ', 'ơ' to 'ợ', 'u' to 'ụ', 'ư' to 'ự', 'y' to 'ỵ'),
    )

    private val vowels = setOf('a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư', 'y')

    /** Process a single character. Returns composing text. */
    fun onChar(c: Char): String {
        val lower = c.lowercaseChar()

        // --- Tone marks ---
        if (lower in toneMap && composedChars.isNotEmpty()) {
            val lastComposed = composedChars.last()
            if (lastComposed in vowels) {
                val toned = toneMap[lower]
                val tonedChar = findAndApplyTone(toned)
                if (tonedChar != null) {
                    rebuildComposedBuffer()
                    return composedBuffer.toString()
                }
            }
        }

        // --- dd → đ ---
        if (lower == 'd' && originalInput.isNotEmpty() && originalInput.last() == 'd' &&
            composedChars.isNotEmpty() && composedChars.last() == 'd') {
            composedChars.last() = 'đ'
            rebuildComposedBuffer()
            return composedBuffer.toString()
        }

        // --- Vowel pair/triple detection (using originalInput for lookup) ---
        if (isVowelBase(lower) && originalInput.isNotEmpty()) {
            val lastOriginal = originalInput.last()

            // Check 3-char triple: original[-2] + original[-1] + new
            if (originalInput.size >= 2) {
                val origPrev2 = originalInput[originalInput.size - 2]
                val triple = "$origPrev2$lastOriginal$lower"
                val tripleResult = vowelTriples[triple]
                if (tripleResult != null) {
                    // Replace last 2 entries in composedChars with triple result
                    // (originalInput stays as-is — it's immutable)
                    composedChars.removeAt(composedChars.size - 1)
                    composedChars.removeAt(composedChars.size - 1)
                    for (ch in tripleResult) {
                        composedChars.add(ch)
                    }
                    rebuildComposedBuffer()
                    return composedBuffer.toString()
                }
            }

            // Check 2-char pair: original[-1] + new
            val pair = "$lastOriginal$lower"
            val pairResult = vowelPairs[pair]
            if (pairResult != null) {
                // Replace last entry in composedChars with pair result
                composedChars.removeAt(composedChars.size - 1)
                for (ch in pairResult) {
                    composedChars.add(ch)
                }
                rebuildComposedBuffer()
                return composedBuffer.toString()
            }
        }

        // --- Normal character ---
        originalInput.add(lower)
        composedChars.add(lower)
        rebuildComposedBuffer()
        return composedBuffer.toString()
    }

    private fun isVowelBase(c: Char): Boolean {
        return c in setOf('a', 'e', 'o', 'u', 'w')
    }

    private fun findAndApplyTone(tonedMap: Map<Char, Char>?): Char? {
        if (tonedMap == null) return null
        for (i in composedChars.size - 1 downTo 0) {
            val ch = composedChars[i]
            val toned = tonedMap[ch]
            if (toned != null) {
                composedChars[i] = toned
                return toned
            }
            if (ch.isLetter() && ch != 'w') break
        }
        return null
    }

    private fun rebuildComposedBuffer() {
        composedBuffer.clear()
        for (ch in composedChars) {
            composedBuffer.append(ch)
        }
    }

    fun onBackspace(): String {
        if (originalInput.isNotEmpty()) {
            originalInput.removeAt(originalInput.size - 1)
            composedChars.removeAt(composedChars.size - 1)
            rebuildComposedBuffer()
        }
        return composedBuffer.toString()
    }

    fun commit(): String {
        val result = composedBuffer.toString()
        originalInput.clear()
        composedChars.clear()
        composedBuffer.clear()
        return result
    }

    fun reset() {
        originalInput.clear()
        composedChars.clear()
        composedBuffer.clear()
    }

    fun getRawBuffer(): String = originalInput.joinToString("")
    fun isEmpty(): Boolean = originalInput.isEmpty()
}
