import Foundation

/// The cleanup every app applies when it DISPLAYS a lot title. The catalogue's title comes
/// from the auctioneer (76% in capitals, 28% with "(Ref.: 53137)") and the API keeps delivering
/// it raw — the source of truth; the presentation lives in the client.
///
/// A port of backend/docs/design-v3/tidy_title.py, tested against its 1,566 golden titles.
/// Where Python and Swift disagree about what a character is, the port follows Python: it
/// works on Unicode scalars, not Swift's grapheme clusters.
enum TitleTidy {
    struct Result: Equatable {
        let headline: String
        let detail: String?
    }

    static func tidy(_ raw: String) -> Result {
        var text = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
        // The source's mojibake: the dash became "¿".
        text = mojibakeDash.replacing(in: text, with: " – ")
        text = text.replacingOccurrences(of: "¿", with: "")
        text = reference.replacing(in: text, with: "")
        text = chassis.replacing(in: text, with: "")
        text = hashCode.replacing(in: text, with: "")
        text = sourceId.replacing(in: text, with: "")
        text = strip(collapsingWhitespace(text))

        var head = text
        var rest: String?
        if let separator = text.range(of: " | ", options: .literal) {
            head = String(text[..<separator.lowerBound])
            rest = String(text[separator.upperBound...])
        }

        head = headlineCase(joiningYears(head))
        guard let rest else { return Result(headline: strip(head), detail: nil) }

        let trimmed = trimWhitespace(rest)
        guard !trimmed.isEmpty else { return Result(headline: strip(head), detail: nil) }
        let detail = headlineCase(joiningYears(trimmed)).replacingOccurrences(of: " | ", with: " · ")
        return Result(headline: strip(head), detail: detail)
    }

    // MARK: Patterns

    private static func pattern(_ source: String, ignoringCase: Bool = false) -> NSRegularExpression {
        // The patterns are literals of this file: a typo is a programming error found
        // by the first test run, not something to recover from.
        try! NSRegularExpression(pattern: source, options: ignoringCase ? [.caseInsensitive] : [])
    }

    private static let mojibakeDash = pattern(#"\s¿\s"#)
    private static let reference = pattern(#"[,\s-]*\(\s*ref\.?\s*:?[^)]*\)"#, ignoringCase: true)
    // "CH.:" with nothing after it, left behind where the chassis number was cut.
    private static let chassis = pattern(#",?\s*CH\.?:?\s*(?=$|,)"#, ignoringCase: true)
    // Codes that only mean something to the auctioneer: "(#175MAGO)", "ID: #3614548".
    private static let hashCode = pattern(#"\s*\(\s*#[^)]*\)"#)
    private static let sourceId = pattern(#"[\s,-]*\bID:?\s*#\w+(?:/\w+)?\s*$"#, ignoringCase: true)
    private static let years = pattern(#"\b((?:19|20)\d\d) ((?:19|20)\d\d)\b"#)

    /// "2010 2011" is a model year written twice; "2010/2011" is how it is read.
    private static func joiningYears(_ text: String) -> String {
        years.replacing(in: text, with: "$1/$2")
    }

    // MARK: Case

    /// A title in capitals is rewritten word by word; a mixed one only has its
    /// shouted words softened ("Máquina Antiga OLIVETTI LINEA 98").
    private static func headlineCase(_ text: String) -> String {
        isMostlyUpper(text) ? titleCase(text) : softenCapsWords(text)
    }

    private static func isMostlyUpper(_ text: String) -> Bool {
        var letters = 0
        var uppercase = 0
        for scalar in text.unicodeScalars where isLetter(scalar) {
            letters += 1
            if scalar.properties.isUppercase { uppercase += 1 }
        }
        guard letters >= 4 else { return false }
        return Double(uppercase) / Double(letters) >= 0.7
    }

    private static let separators: Set<Unicode.Scalar> = ["/", "-", ".", ",", ";", ":", "(", ")", "+", "&", "|"]

    private static func titleCase(_ text: String) -> String {
        var output = String.UnicodeScalarView()
        var word = String.UnicodeScalarView()
        var first = true

        func flush() {
            guard !word.isEmpty else { return }
            output.append(contentsOf: fixWord(String(word), first: first).unicodeScalars)
            first = false
            word.removeAll()
        }

        for scalar in text.unicodeScalars {
            if isWhitespace(scalar) || separators.contains(scalar) {
                flush()
                output.append(scalar)
            } else {
                word.append(scalar)
            }
        }
        flush()
        return String(output)
    }

    private static let capitals: Set<Unicode.Scalar> = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZÁÀÂÃÉÊÍÓÔÕÚÇ".unicodeScalars)

    /// Every run of four or more capitals that stands alone as a word. The
    /// neighbours must not be word characters, or it is part of a code ("XEI20FLEX").
    private static func softenCapsWords(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            guard capitals.contains(scalars[index]) else {
                output.append(scalars[index])
                index += 1
                continue
            }
            var end = index
            while end < scalars.count, capitals.contains(scalars[end]) { end += 1 }
            let standsAlone = end - index >= 4
                && (index == 0 || !isWordCharacter(scalars[index - 1]))
                && (end == scalars.count || !isWordCharacter(scalars[end]))
            if standsAlone {
                var run = String.UnicodeScalarView()
                run.append(contentsOf: scalars[index..<end])
                output.append(contentsOf: fixWord(String(run), first: false).unicodeScalars)
            } else {
                output.append(contentsOf: scalars[index..<end])
            }
            index = end
        }
        return String(output)
    }

    // MARK: Words

    // Portuguese connectors: lower case, except as the first word.
    private static let connectors: Set<String> = [
        "e", "à", "á", "ao", "as", "da", "de", "do", "em", "na", "no", "os", "ou", "um", "aos",
        "até", "com", "das", "dos", "nas", "nos", "por", "que", "sem", "sob", "uma", "para",
        "pela", "pelo", "entre", "sobre",
    ]

    // Short words (up to three letters) that must become "Kit", "Aço", "Ano": the
    // rest of the catalogue's short tokens are codes (ELX, FIV, GL, LED, ID).
    private static let shortWords: Set<String> = [
        "ar", "po", "pá", "pé", "pó", "yo", "aco", "air", "alt", "ano", "aro", "aço", "bar",
        "baú", "bem", "boi", "bom", "box", "cal", "cor", "cão", "dez", "dia", "fim", "fio",
        "fit", "gir", "gol", "gás", "imp", "kia", "kit", "lar", "lei", "luz", "mal", "mar",
        "max", "meu", "mil", "mãe", "mão", "mês", "new", "não", "ovo", "par", "pia", "pro",
        "pão", "pés", "ref", "rei", "rio", "rua", "sal", "ser", "seu", "sim", "sol", "som",
        "sua", "sul", "ter", "tia", "tom", "top", "uma", "uno", "uso", "vez", "gato", "lado",
        "três", "tubo", "óleo",
    ]

    // Acronyms that must not become "Suv" or "Abs". Tokens of up to three letters
    // without a vowel (VW, GM, LS, GL, KG, HP, CV) already stay in capitals.
    private static let acronyms: Set<String> = [
        "AT", "CD", "EX", "HD", "ID", "II", "IV", "IX", "ME", "MT", "NF", "PC", "RG", "TV",
        "VI", "XI", "ZF", "ABS", "AWD", "CNH", "CPF", "CVT", "DSG", "DUT", "EPI", "EPP",
        "EXL", "GLS", "GLX", "GPS", "III", "KVA", "LCD", "LED", "MDF", "PVC", "RAM", "SSD",
        "SUV", "TSI", "USB", "UTI", "VII", "XEI", "XII", "CNPJ", "IPTU", "IPVA", "VIII", "DVD",
    ]

    // State codes: "Rosário Do Sul-RS" and "(SP)" must not become "Rs" and "Sp".
    private static let states: Set<String> = [
        "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT", "PA",
        "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO",
    ]

    private static let vowels: Set<Unicode.Scalar> = Set("AEIOUÁÀÂÃÉÊÍÓÔÕÚ".unicodeScalars)

    /// Capitalises one word (no punctuation at its ends) of a title in capitals.
    static func fixWord(_ word: String, first: Bool) -> String {
        guard !word.isEmpty else { return word }
        let scalars = Array(word.unicodeScalars)
        // 1.0MT, 4X4, 16VH, XEI20FLEX: model codes stay as they are.
        if scalars.contains(where: isDigit) { return word }

        let upper = word.uppercased()
        let lower = word.lowercased()
        if connectors.contains(lower) { return first ? capitalized(word) : lower }
        if acronyms.contains(upper) || states.contains(upper) || isRoman(upper) { return upper }
        if shortWords.contains(lower) { return capitalized(word) }
        // VW, GM, GL, ELX, FIV, LED, KG: a code, not a word.
        if scalars.count <= 3 { return upper }
        // CSLC, KLTS: without a vowel it is not a word either.
        if !upper.unicodeScalars.contains(where: vowels.contains) { return upper }
        return capitalized(word)
    }

    private static func capitalized(_ word: String) -> String {
        let scalars = word.unicodeScalars
        guard let first = scalars.first else { return word }
        return String(first).uppercased() + String(scalars.dropFirst()).lowercased()
    }

    private static func isRoman(_ upper: String) -> Bool {
        !upper.isEmpty && upper.unicodeScalars.allSatisfy { $0 == "I" || $0 == "V" || $0 == "X" }
    }

    // MARK: Python's character classes

    // `str.isalpha`: the Unicode letter categories.
    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return true
        default: return false
        }
    }

    // `str.isdigit`: decimal digits and the superscripts and circled digits ("m²").
    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.numericType {
        case .decimal?, .digit?: return true
        default: return false
        }
    }

    // `\w`: letters, any numeric character, and the underscore.
    private static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || isLetter(scalar) || scalar.properties.numericType != nil
    }

    // `\s` and `str.isspace`: the ASCII whitespace and separators, plus the Unicode
    // spaces. Not the same set as Swift's `isWhitespace`, which omits U+001C-001F.
    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }

    // MARK: Trimming

    private static func collapsingWhitespace(_ text: String) -> String {
        var output = String.UnicodeScalarView()
        var inRun = false
        for scalar in text.unicodeScalars {
            if isWhitespace(scalar) {
                if !inRun { output.append(" ") }
                inRun = true
            } else {
                output.append(scalar)
                inRun = false
            }
        }
        return String(output)
    }

    private static let stripped: Set<Unicode.Scalar> = [" ", ",", "-", "–"]

    private static func strip(_ text: String) -> String {
        trim(text) { stripped.contains($0) }
    }

    private static func trimWhitespace(_ text: String) -> String {
        trim(text, where: isWhitespace)
    }

    private static func trim(_ text: String, where isTrimmed: (Unicode.Scalar) -> Bool) -> String {
        let scalars = text.unicodeScalars
        var start = scalars.startIndex
        var end = scalars.endIndex
        while start < end, isTrimmed(scalars[start]) { start = scalars.index(after: start) }
        while start < end {
            let before = scalars.index(before: end)
            guard isTrimmed(scalars[before]) else { break }
            end = before
        }
        return String(scalars[start..<end])
    }
}

private extension NSRegularExpression {
    func replacing(in text: String, with template: String) -> String {
        stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}
