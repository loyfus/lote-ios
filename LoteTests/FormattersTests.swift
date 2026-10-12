import XCTest
@testable import Lote

/// The strings a reader actually sees, with the vectors of docs/DESIGN_SYSTEM.md §4.
/// The Android client is tested against the same table: a difference between the
/// two apps is a defect, and these are where it would show first.
final class FormattersTests: XCTestCase {

    private let nbsp = "\u{00A0}"

    private func brl(_ value: String) -> String { "R$\(nbsp)\(value)" }

    // MARK: price

    func testAnAbsentPriceSaysSoInsteadOfInventingAZero() {
        XCTAssertEqual(Fmt.price(nil), "Sob consulta")
        XCTAssertEqual(Fmt.priceShort(nil), "Sob consulta")
        XCTAssertEqual(Fmt.price(0), brl("0"))
    }

    func testPriceShowsCentsOnlyWhenTheyAreNotZero() {
        XCTAssertEqual(Fmt.price(7637.8), brl("7.637,80"))
        XCTAssertEqual(Fmt.price(81000), brl("81.000"))
        XCTAssertEqual(Fmt.price(0.3), brl("0,30"))
        XCTAssertEqual(Fmt.price(12_510_000), brl("12.510.000"))
        XCTAssertEqual(Fmt.price(44_772_396.73), brl("44.772.396,73"))
        XCTAssertEqual(Fmt.price(1234.05), brl("1.234,05"))
    }

    func testThePriceSpaceIsANoBreakSpace() {
        XCTAssertTrue(Fmt.price(100).hasPrefix("R$\u{00A0}"))
        XCTAssertFalse(Fmt.price(100).contains(" "))
    }

    func testPriceShortIsPriceBelowAMillion() {
        for value in [0.3, 7637.8, 81_000, 999_999.99] {
            XCTAssertEqual(Fmt.priceShort(value), Fmt.price(value))
        }
    }

    func testPriceShortFromAMillionUsesOneDecimalAndDropsAZero() {
        XCTAssertEqual(Fmt.priceShort(12_510_000), brl("12,5") + nbsp + "mi")
        XCTAssertEqual(Fmt.priceShort(1_573_818.2), brl("1,6") + nbsp + "mi")
        XCTAssertEqual(Fmt.priceShort(2_000_000), brl("2") + nbsp + "mi")
        XCTAssertEqual(Fmt.priceShort(1_000_000), brl("1") + nbsp + "mi")
        XCTAssertEqual(Fmt.priceShort(9_960_000), brl("10") + nbsp + "mi")
        XCTAssertEqual(Fmt.priceShort(1_234_000_000), brl("1.234") + nbsp + "mi")
    }

    func testPriceShortNeverGrowsPastTheFullPriceItShortens() {
        for value in [1_000_000.0, 12_510_000, 44_772_396.73, 1_573_818.2] {
            XCTAssertLessThanOrEqual(Fmt.priceShort(value).count, Fmt.price(value).count)
        }
    }

    func testCountsInASentenceAreGrouped() {
        XCTAssertEqual(Fmt.thousands(6394), "6.394")
        XCTAssertEqual(Fmt.thousands(1_298_000), "1.298.000")
        XCTAssertEqual(Fmt.thousands(0), "0")
        XCTAssertEqual(Fmt.thousands(999), "999")
    }

    func testLotsAgreeInNumber() {
        XCTAssertEqual(Fmt.lots(1), "1 lote")
        XCTAssertEqual(Fmt.lots(0), "0 lotes")
        XCTAssertEqual(Fmt.lots(4691), "4.691 lotes")
    }

    func testAmountsOfAPriceFilterAreCompact() {
        XCTAssertEqual(Fmt.compactAmount(1_000), "1" + nbsp + "mil")
        XCTAssertEqual(Fmt.compactAmount(1_500), "1,5" + nbsp + "mil")
        XCTAssertEqual(Fmt.compactAmount(50_000), "50" + nbsp + "mil")
        XCTAssertEqual(Fmt.compactAmount(2_000_000), "2" + nbsp + "mi")
        XCTAssertEqual(Fmt.compactAmount(900), "900")
    }

    func testThePriceFilterTagReadsInOnePhrase() {
        XCTAssertNil(Fmt.priceRange(min: nil, max: nil))
        XCTAssertEqual(Fmt.priceRange(min: 1_000, max: 50_000), "R$" + nbsp + "1" + nbsp + "mil – 50" + nbsp + "mil")
        XCTAssertEqual(Fmt.priceRange(min: nil, max: 1_000), "Até R$" + nbsp + "1" + nbsp + "mil")
        XCTAssertEqual(Fmt.priceRange(min: 200_000, max: nil), "Acima de R$" + nbsp + "200" + nbsp + "mil")
    }

    // MARK: time left

    private let hour = 3_600
    private let day = 86_400

    func testTimeLeftReadsInTheUnitPairThatMatters() {
        XCTAssertEqual(Fmt.timeLeft(0), "Encerrado")
        XCTAssertEqual(Fmt.timeLeft(-1), "Encerrado")
        XCTAssertEqual(Fmt.timeLeft(35 * day + 3 * hour), "35d")
        XCTAssertEqual(Fmt.timeLeft(10 * day), "10d")
        XCTAssertEqual(Fmt.timeLeft(9 * day + 23 * hour), "9d 23h")
        XCTAssertEqual(Fmt.timeLeft(4 * day + 15 * hour + 600), "4d 15h")
        XCTAssertEqual(Fmt.timeLeft(day), "1d 0h")
        XCTAssertEqual(Fmt.timeLeft(day - 1), "23h 59min")
        XCTAssertEqual(Fmt.timeLeft(5 * hour + 20 * 60), "5h 20min")
        XCTAssertEqual(Fmt.timeLeft(hour), "1h 0min")
        XCTAssertEqual(Fmt.timeLeft(hour - 1), "59min")
        XCTAssertEqual(Fmt.timeLeft(42 * 60 + 8), "42min")
        XCTAssertEqual(Fmt.timeLeft(60), "1min")
        XCTAssertEqual(Fmt.timeLeft(59), "<1min")
        XCTAssertEqual(Fmt.timeLeft(1), "<1min")
    }

    func testTheLiveCountdownCountsSecondsInTheLastTenMinutes() {
        XCTAssertEqual(Fmt.timeLeftLive(0), "Encerrado")
        XCTAssertEqual(Fmt.timeLeftLive(48), "48s")
        XCTAssertEqual(Fmt.timeLeftLive(60), "1min 0s")
        XCTAssertEqual(Fmt.timeLeftLive(3 * 60 + 12), "3min 12s")
        XCTAssertEqual(Fmt.timeLeftLive(599), "9min 59s")
        XCTAssertEqual(Fmt.timeLeftLive(600), "10min")
        XCTAssertEqual(Fmt.timeLeftLive(42 * 60), "42min")
        XCTAssertEqual(Fmt.timeLeftLive(5 * hour + 20 * 60), "5h 20min")
        XCTAssertEqual(Fmt.timeLeftLive(4 * day + 15 * hour), "4d 15h")
    }

    func testASpokenDeadlineIsInWordsAScreenReaderCanSay() {
        XCTAssertEqual(Fmt.timeLeftSpoken(0), "encerrado")
        XCTAssertEqual(Fmt.timeLeftSpoken(35 * day), "35 dias")
        XCTAssertEqual(Fmt.timeLeftSpoken(4 * day + 15 * hour), "4 dias e 15 horas")
        XCTAssertEqual(Fmt.timeLeftSpoken(day + 3_600), "1 dia e 1 hora")
        XCTAssertEqual(Fmt.timeLeftSpoken(5 * hour + 20 * 60), "5 horas e 20 minutos")
        XCTAssertEqual(Fmt.timeLeftSpoken(2 * hour), "2 horas")
        XCTAssertEqual(Fmt.timeLeftSpoken(42 * 60), "42 minutos")
        XCTAssertEqual(Fmt.timeLeftSpoken(30), "menos de 1 minuto")
    }

    // MARK: counts

    func testBidCountsAgreeWithEachOther() {
        XCTAssertEqual(Fmt.bids(0), "Sem lances")
        XCTAssertEqual(Fmt.bids(1), "1 lance")
        XCTAssertEqual(Fmt.bids(104), "104 lances")
    }

    func testParticipantsAgreeInNumber() {
        XCTAssertEqual(Fmt.participants(1), "1 participante")
        XCTAssertEqual(Fmt.participants(2), "2 participantes")
        XCTAssertEqual(Fmt.participants(0), "0 participantes")
    }

    // MARK: dates

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ iso: String) -> Date { Fmt.parse(iso)! }

    func testTheEndLabelNamesTheDayAndTheClock() {
        let now = date("2026-10-10T12:00:00Z")
        XCTAssertEqual(Fmt.endLabel("2026-10-15T14:12:00Z", now: now, calendar: calendar("UTC")),
                       "qui, 15 out · 14:12")
        XCTAssertEqual(Fmt.endLabel("2026-01-04T09:05:00Z", now: now, calendar: calendar("UTC")),
                       "dom, 4 jan · 09:05")
    }

    func testTheEndLabelShowsTheYearOnlyWhenItIsNotTheCurrentOne() {
        let now = date("2026-10-10T12:00:00Z")
        XCTAssertEqual(Fmt.endLabel("2027-10-14T14:12:00Z", now: now, calendar: calendar("UTC")),
                       "qui, 14 out 2027 · 14:12")
        XCTAssertEqual(Fmt.endLabel("2025-12-31T23:59:00Z", now: now, calendar: calendar("UTC")),
                       "qua, 31 dez 2025 · 23:59")
    }

    func testTheEndLabelFollowsTheDeviceTimeZone() {
        let now = date("2026-10-10T12:00:00Z")
        XCTAssertEqual(Fmt.endLabel("2026-10-15T14:12:00Z", now: now, calendar: calendar("America/Sao_Paulo")),
                       "qui, 15 out · 11:12")
        // Across midnight the weekday and the day move with the zone.
        XCTAssertEqual(Fmt.endLabel("2026-10-16T02:30:00Z", now: now, calendar: calendar("America/Sao_Paulo")),
                       "qui, 15 out · 23:30")
    }

    func testTheEndLabelReadsTheApisFractionalSeconds() {
        let now = date("2026-10-10T12:00:00Z")
        XCTAssertEqual(Fmt.endLabel("2026-10-11T06:59:13.418252Z", now: now, calendar: calendar("UTC")),
                       "dom, 11 out · 06:59")
        XCTAssertNil(Fmt.endLabel(nil))
        XCTAssertNil(Fmt.endLabel("not a date"))
    }

    func testTheClockIsTwentyFourHours() {
        XCTAssertEqual(Fmt.clock("2026-10-11T01:27:13.418252Z", calendar: calendar("UTC")), "01:27")
        XCTAssertEqual(Fmt.clock("2026-10-11T01:27:13Z", calendar: calendar("America/Sao_Paulo")), "22:27")
    }

    func testAgoSpeaksInTheLargestWholeUnit() {
        let now = date("2026-10-10T12:00:00Z")
        func ago(_ seconds: Int) -> String? {
            Fmt.ago(ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-seconds))), now: now)
        }
        XCTAssertEqual(ago(0), "agora")
        XCTAssertEqual(ago(30), "agora")
        XCTAssertEqual(ago(59), "agora")
        XCTAssertEqual(ago(60), "há 1 min")
        XCTAssertEqual(ago(12 * 60), "há 12 min")
        XCTAssertEqual(ago(3_599), "há 59 min")
        XCTAssertEqual(ago(3_600), "há 1 h")
        XCTAssertEqual(ago(3 * 3_600 + 1_000), "há 3 h")
        XCTAssertEqual(ago(86_399), "há 23 h")
        XCTAssertEqual(ago(86_400), "há 1 d")
        XCTAssertEqual(ago(2 * 86_400 + 5), "há 2 d")
        XCTAssertEqual(ago(-300), "agora", "a clock that runs ahead of the server must not print the future")
        XCTAssertNil(Fmt.ago(nil))
    }

    // MARK: place

    func testThePlaceIsTheFirstStretchOfTheDetailThatEndsInAState() {
        XCTAssertEqual(
            Fmt.place("Rosário Do Sul-RS · Vila Nova - Financiamento até 420 Meses!"), "Rosário Do Sul-RS")
        XCTAssertEqual(Fmt.place("Santana da Vargem-MG"), "Santana da Vargem-MG")
        XCTAssertEqual(Fmt.place("Igarassu-PE · Res. Agamenon · Agamenon Magalhães"), "Igarassu-PE")
    }

    func testNoPlaceIsInventedWhenTheTitleHasNone() {
        XCTAssertNil(Fmt.place(nil))
        XCTAssertNil(Fmt.place(""))
        XCTAssertNil(Fmt.place("Vila Nova - Financiamento até 420 Meses!"))
        XCTAssertNil(Fmt.place("Centro · Excelente localização"))
    }

    // MARK: specifications

    func testSpecificationsLeadWithWhatABuyerDecidesOn() {
        let specs = [
            "Zeta": "z", "Cor": "Prata", "Quilometragem": "31505", "Marca": "Chevrolet",
            "Ano Modelo": "2025", "Modelo": "Spin", "Placa": "ABC1D23",
        ]
        XCTAssertEqual(
            Fmt.specOrder(specs).map(\.key),
            ["Marca", "Modelo", "Ano Modelo", "Cor", "Placa", "Quilometragem", "Zeta"])
    }

    func testTheRestOfTheSpecificationsFollowPortugueseAlphabeticalOrder() {
        let specs = ["Zeta": "1", "Área Total": "2", "Ótimo": "3", "Acabamento": "4", "Banheiros": "5", "Dormitórios": "6"]
        // Code-point order would put "Zeta" first and "Área Total" last.
        XCTAssertEqual(
            Fmt.specOrder(specs).map(\.key),
            ["Banheiros", "Acabamento", "Área Total", "Dormitórios", "Ótimo", "Zeta"])
    }

    func testSpecificationsKeepTheirValues() {
        let ordered = Fmt.specOrder(["Modelo": "Spin", "Marca": "Chevrolet"])
        XCTAssertEqual(ordered.map(\.value), ["Chevrolet", "Spin"])
        XCTAssertTrue(Fmt.specOrder([:]).isEmpty)
    }
}
