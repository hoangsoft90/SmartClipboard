package com.smartclip.smartclipboard

/**
 * VietnameseTelexProcessor — Telex input engine for Vietnamese.
 *
 * Telex mapping (standard):
 *   Vowels with circumflex:  aa→â, ee→ê, oo→ô
 *   Vowels with breve/horn:  aw→ă, ow→ơ, uw→ư
 *   d with stroke:           dd→đ
 *   Tone marks (applied to last vowel of the base):
 *     s→sac(á), f→huyen(à), r→hoi(ả), x→nga(ã), j→nang(ạ)
 *
 * Flow: onChar() buffers raw Latin, returns composing text with diacritics.
 *       onBackspace() removes last char from buffer.
 *       commit() finalizes the word and returns the composed string.
 */
class VietnameseTelexProcessor {

    private val rawBuffer = StringBuilder()

    // Mapping: raw lowercase sequence → composed Vietnamese char
    private val vowelMap = mapOf(
        "aa" to "â",
        "ee" to "ê",
        "oo" to "ô",
        "aw" to "ă",
        "ow" to "ơ",
        "uw" to "ư",
    )

    // Tone marks: letter → (base→toned mapping)
    private val toneMap = mapOf(
        's' to mapOf('a' to 'á', 'ă' to 'ắ', 'â' to 'ấ', 'e' to 'é', 'ê' to 'ế', 'i' to 'í', 'o' to 'ó', 'ô' to 'ố', 'ơ' to 'ớ', 'u' to 'ú', 'ư' to 'ứ', 'y' to 'ý'),
        'f' to mapOf('a' to 'à', 'ă' to 'ằ', 'â' to 'ầ', 'e' to 'è', 'ê' to 'ề', 'i' to 'ì', 'o' to 'ò', 'ô' to 'ồ', 'ơ' to 'ờ', 'u' to 'ù', 'ư' to 'ừ', 'y' to 'ỳ'),
        'r' to mapOf('a' to 'ả', 'ă' to 'ẳ', 'â' to 'ẩ', 'e' to 'ẻ', 'ê' to 'ể', 'i' to 'ỉ', 'o' to 'ỏ', 'ô' to 'ổ', 'ơ' to 'ở', 'u' to 'ủ', 'ư' to 'ử', 'y' to 'ỷ'),
        'x' to mapOf('a' to 'ã', 'ă' to 'ẵ', 'â' to 'ẫ', 'e' to 'ẽ', 'ê' to 'ễ', 'i' to 'ĩ', 'o' to 'õ', 'ô' to 'ỗ', 'ơ' to 'ỡ', 'u' to 'ũ', 'ư' to 'ữ', 'y' to 'ỹ'),
        'j' to mapOf('a' to 'ạ', 'ă' to 'ặ', 'â' to 'ậ', 'e' to 'ẹ', 'ê' to 'ệ', 'i' to 'ị', 'o' to 'ọ', 'ô' to 'ộ', 'ơ' to 'ợ', 'u' to 'ụ', 'ư' to 'ự', 'y' to 'ỵ'),
    )

    // Diphthongs that should not be split by vowel mapping
    // e.g. "oa", "oe", "uy", "ua", "ia", "ua", "ieu", "oai", etc.
    // These are handled by composing vowels in order.
    private val diphthongs = setOf(
        "oa", "oe", "ai", "ao", "au", "ay", "eo", "eu",
        "ia", "ie", "iu", "oa", "oe", "oi", "oo", "ou",
        "ua", "ue", "ui", "uo", "uy",
        "uya",
    )

    /** Process a single character input. Returns the composing text (with diacritics applied). */
    fun onChar(c: Char): String {
        val lower = c.lowercaseChar()

        // Tone marks: if last char in buffer is a vowel and this is a tone key
        if (lower in toneMap && rawBuffer.isNotEmpty()) {
            val lastRaw = rawBuffer.last()
            if (lastRaw.isLetter() && lastRaw != 'd') {
                val toned = toneMap[lower]
                // Find the last vowel in the buffer to apply tone to
                val tonedChar = findAndApplyTone(toned)
                if (tonedChar != null) {
                    return composeBuffer()
                }
            }
            // If tone can't apply (e.g. on consonant), treat as normal char
        }

        // Check for double-vowel → circumflex/horn mapping
        if (rawBuffer.isNotEmpty()) {
            val lastChar = rawBuffer.last()
            val pair = "$lastChar$lower"
            val mapped = vowelMap[pair]
            if (mapped != null) {
                // Replace last char with composed vowel
                rawBuffer.deleteCharAt(rawBuffer.length - 1)
                rawBuffer.append(mapped)
                return composeBuffer()
            }
        }

        // dd → đ
        if (lower == 'd' && rawBuffer.isNotEmpty() && rawBuffer.last() == 'd') {
            rawBuffer.deleteCharAt(rawBuffer.length - 1)
            rawBuffer.append('đ')
            return composeBuffer()
        }

        // Normal character: append to buffer
        rawBuffer.append(lower)
        return composeBuffer()
    }

    /**
     * Try to apply tone to the last vowel in the buffer.
     * Returns true if tone was applied.
     */
    private fun findAndApplyTone(tonedMap: Map<Char, Char>?): Char? {
        if (tonedMap == null) return null

        // Walk backwards to find the last vowel
        for (i in rawBuffer.length - 1 downTo 0) {
            val ch = rawBuffer[i]
            val toned = tonedMap[ch]
            if (toned != null) {
                rawBuffer[i] = toned
                return toned
            }
            // If we hit a consonant that's not part of a vowel cluster, stop
            if (ch.isLetter() && ch != 'w') break
        }
        return null
    }

    /** Handle backspace: remove last char from buffer. Returns composing text. */
    fun onBackspace(): String {
        if (rawBuffer.isNotEmpty()) {
            rawBuffer.deleteCharAt(rawBuffer.length - 1)
        }
        return composeBuffer()
    }

    /** Commit the current word. Returns the final composed string and clears buffer. */
    fun commit(): String {
        val result = composeBuffer()
        rawBuffer.clear()
        return result
    }

    /** Reset the processor state. */
    fun reset() {
        rawBuffer.clear()
    }

    /** Get current raw buffer (for debugging). */
    fun getRawBuffer(): String = rawBuffer.toString()

    /**
     * Compose the raw buffer into Vietnamese text with diacritics.
     * Simple approach: raw chars are already mapped to Vietnamese chars in the buffer
     * (e.g., "a" stays "a", "â" is stored directly, "á" is stored directly).
     * This method just returns the buffer as-is since mapping happens in real-time.
     */
    private fun composeBuffer(): String {
        return rawBuffer.toString()
    }

    /** Check if buffer is empty. */
    fun isEmpty(): Boolean = rawBuffer.isEmpty()
}
