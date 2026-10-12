import Foundation

/// The strings a reader actually sees, written once. The rules are the contract of
/// docs/DESIGN_SYSTEM.md §4 and are tested against the same vectors as the
/// Android client. Nothing here reads a locale or a formatter from the system:
/// the format of a price is a product decision, not a setting of the device.
enum Fmt {
    static let nbsp = "\u{00A0}"

    // Brazilian auctions seal the opening bid on some lots; showing "R$ 0,00" would be a lie.
    static let priceOnRequest = "Sob consulta"

    // MARK: Money

    /// `R$ 7.637,80`, `R$ 81.000`: cents only when they are not zero.
    static func price(_ value: Double?) -> String {
        guard let value else { return priceOnRequest }
        let cents = Int64((value * 100).rounded())
        let whole = abs(cents) / 100
        let fraction = abs(cents) % 100
        var text = grouped(whole)
        if fraction != 0 { text += "," + (fraction < 10 ? "0" : "") + String(fraction) }
        return "R$" + nbsp + (cents < 0 ? "-" : "") + text
    }

    /// Like `price` below a million; from there `R$ 12,5 mi`, one decimal, a zero
    /// decimal dropped. Tiles and rows, where a seven-figure price would otherwise
    /// take the width of its caption.
    static func priceShort(_ value: Double?) -> String {
        guard let value else { return priceOnRequest }
        guard value >= 1_000_000 else { return price(value) }
        let tenths = Int64((value / 100_000).rounded(.toNearestOrAwayFromZero))
        let whole = tenths / 10
        let decimal = tenths % 10
        return "R$" + nbsp + grouped(whole) + (decimal == 0 ? "" : "," + String(decimal)) + nbsp + "mi"
    }

    /// 6.394, not 6394: counts inside a sentence.
    static func thousands(_ value: Int) -> String {
        (value < 0 ? "-" : "") + grouped(Int64(abs(value)))
    }

    /// Whole-number amounts as a filter shows them: `1 mil`, `1,5 mil`, `2 mi`.
    static func compactAmount(_ value: Int) -> String {
        func scaled(_ amount: Double, _ unit: String) -> String {
            let tenths = Int64((amount * 10).rounded())
            let decimal = tenths % 10
            return grouped(tenths / 10) + (decimal == 0 ? "" : "," + String(decimal)) + nbsp + unit
        }
        if value >= 1_000_000 { return scaled(Double(value) / 1_000_000, "mi") }
        if value >= 1_000 { return scaled(Double(value) / 1_000, "mil") }
        return String(value)
    }

    private static func grouped(_ value: Int64) -> String {
        let digits = String(value)
        var result = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { result.append(".") }
            result.append(character)
        }
        return String(result.reversed())
    }

    // MARK: Counts

    static func bids(_ count: Int) -> String {
        switch count {
        case 0: return "Sem lances"
        case 1: return "1 lance"
        default: return "\(count) lances"
        }
    }

    static func participants(_ count: Int) -> String {
        count == 1 ? "1 participante" : "\(count) participantes"
    }

    static func lots(_ count: Int) -> String {
        count == 1 ? "1 lote" : "\(thousands(count)) lotes"
    }

    // MARK: Time left

    private static let day = 86_400

    /// `35d`, `4d 15h`, `5h 20min`, `42min`, `<1min`: one unit pair, never more.
    static func timeLeft(_ seconds: Int) -> String {
        guard seconds > 0 else { return "Encerrado" }
        let d = seconds / day
        let h = (seconds % day) / 3_600
        let m = (seconds % 3_600) / 60
        if d >= 10 { return "\(d)d" }
        if d >= 1 { return "\(d)d \(h)h" }
        if h >= 1 { return "\(h)h \(m)min" }
        if m >= 1 { return "\(m)min" }
        return "<1min"
    }

    /// As `timeLeft`, but the last ten minutes count in seconds. Only the detail
    /// screen, where the number is a live countdown.
    static func timeLeftLive(_ seconds: Int) -> String {
        guard seconds > 0 else { return "Encerrado" }
        guard seconds < 600 else { return timeLeft(seconds) }
        let m = seconds / 60
        let s = seconds % 60
        return m >= 1 ? "\(m)min \(s)s" : "\(s)s"
    }

    /// The same duration, in words a screen reader pronounces as written:
    /// "4d 15h" is read letter by letter, "4 dias e 15 horas" is not.
    static func timeLeftSpoken(_ seconds: Int) -> String {
        guard seconds > 0 else { return "encerrado" }
        func unit(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }
        let d = seconds / day
        let h = (seconds % day) / 3_600
        let m = (seconds % 3_600) / 60
        if d >= 10 { return unit(d, "dia", "dias") }
        if d >= 1 { return unit(d, "dia", "dias") + (h > 0 ? " e " + unit(h, "hora", "horas") : "") }
        if h >= 1 { return unit(h, "hora", "horas") + (m > 0 ? " e " + unit(m, "minuto", "minutos") : "") }
        if m >= 1 { return unit(m, "minuto", "minutos") }
        return "menos de 1 minuto"
    }

    // MARK: Dates

    private static let weekdays = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
    private static let months = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    // ISO8601DateFormatter is documented thread-safe, so the two are shared.
    private static let isoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// The API writes instants in UTC, with or without fractional seconds.
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFraction.date(from: value) ?? isoPlain.date(from: value)
    }

    /// `qui, 15 out · 14:12`, in the device's time zone, with the year only when it
    /// is not the current one. Abbreviations are written out here rather than taken
    /// from the system, which puts a period after them and moves it between releases.
    static func endLabel(
        _ iso: String?, now: Date = Date(), calendar: Calendar = .current
    ) -> String? {
        guard let date = parse(iso) else { return nil }
        let c = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        guard let year = c.year, let month = c.month, let day = c.day, let weekday = c.weekday,
              let hour = c.hour, let minute = c.minute else { return nil }
        let thisYear = calendar.component(.year, from: now)
        let yearPart = year == thisYear ? "" : " \(year)"
        return "\(weekdays[weekday - 1]), \(day) \(months[month - 1])\(yearPart) · \(twoDigits(hour)):\(twoDigits(minute))"
    }

    /// `14:12`, in the device's time zone.
    static func clock(_ iso: String?, calendar: Calendar = .current) -> String? {
        guard let date = parse(iso) else { return nil }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = c.hour, let minute = c.minute else { return nil }
        return "\(twoDigits(hour)):\(twoDigits(minute))"
    }

    /// `agora`, `há 12 min`, `há 3 h`, `há 2 d`.
    static func ago(_ iso: String?, now: Date = Date()) -> String? {
        guard let date = parse(iso) else { return nil }
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "agora" }
        if seconds < 3_600 { return "há \(seconds / 60) min" }
        if seconds < day { return "há \(seconds / 3_600) h" }
        return "há \(seconds / day) d"
    }

    /// Minutes since `iso`, for the freshness dot.
    static func minutesSince(_ iso: String?, now: Date = Date()) -> Int? {
        guard let date = parse(iso) else { return nil }
        return Int(now.timeIntervalSince(date)) / 60
    }

    private static func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

    // MARK: Place and specifications

    // The place of an item is not the city of its auction event: every lot of the
    // catalogue says "São Paulo - SP". When the seller wrote it into the title
    // ("… | Rosário Do Sul-RS | …") the tidy title's detail starts with it.
    private static let placePattern = try! NSRegularExpression(pattern: "^(.+?-[A-Z]{2})(?: · |$)")

    static func place(_ detail: String?) -> String? {
        guard let detail else { return nil }
        let range = NSRange(detail.startIndex..., in: detail)
        guard let match = placePattern.firstMatch(in: detail, range: range),
              let group = Range(match.range(at: 1), in: detail) else { return nil }
        return String(detail[group])
    }

    /// The attributes a buyer decides on come first, in this order; the rest follow
    /// alphabetically. The API's own order is arbitrary, and one criterion for both
    /// platforms is what keeps the two sheets identical.
    static let specPriority = [
        "Marca", "Modelo", "Ano Modelo", "Ano Fabricação", "Cor", "Placa", "Combustível", "Câmbio",
        "Quilometragem", "Valor Tabela FIPE", "Deságio", "Área do Terreno", "Área Construída",
        "Quartos", "Banheiros", "Vagas", "Endereço", "Número da Matrícula", "Subtipo",
        "Condições de Pagamento",
    ]

    static func specOrder(_ specs: [String: String]) -> [(key: String, value: String)] {
        var ordered: [(key: String, value: String)] = []
        for key in specPriority {
            if let value = specs[key] { ordered.append((key, value)) }
        }
        let priority = Set(specPriority)
        let portuguese = Locale(identifier: "pt_BR")
        let rest = specs.filter { !priority.contains($0.key) }.sorted {
            let order = $0.key.compare($1.key, options: [], range: nil, locale: portuguese)
            return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
        }
        return ordered + rest.map { ($0.key, $0.value) }
    }

    // MARK: Filters

    /// The tag of a price filter: `R$ 1 mil – 50 mil`, `Até R$ 1 mil`, `Acima de R$ 200 mil`.
    static func priceRange(min: Int?, max: Int?) -> String? {
        switch (min, max) {
        case (nil, nil): return nil
        case let (low?, high?): return "R$" + nbsp + compactAmount(low) + " – " + compactAmount(high)
        case let (nil, high?): return "Até R$" + nbsp + compactAmount(high)
        case let (low?, nil): return "Acima de R$" + nbsp + compactAmount(low)
        }
    }
}
