import XCTest
@testable import Loyfus

/// What a tile prints about a lot, and how a lot is classified. Lots are built from
/// JSON the way the API sends them (null values simply absent), so the same tests
/// cover the tolerant decoding.
final class LotDisplayTests: XCTestCase {

    static func summary(
        id: Int = 1, title: String = "CHEVROLET CLASSIC LS 2010 2011 CINZA", modality: String? = "LEILAO",
        secondsToClose: Int = 4 * 86_400, endsAt: String? = "2026-10-15T14:12:00Z",
        price: Double? = 7637.8, bids: Int = 1, acceptsProposal: Bool? = nil
    ) -> LotSummary {
        var json: [String: Any] = [
            "id": id, "title": title, "bidCount": bids, "endingSoon": false, "secondsToClose": secondsToClose,
        ]
        json["modality"] = modality
        json["endsAt"] = endsAt
        json["currentPrice"] = price
        json["acceptsProposal"] = acceptsProposal
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(LotSummary.self, from: data)
    }

    // MARK: kind and urgency

    func testOnlyAfterMarketLotsAreDirectSales() {
        XCTAssertEqual(Self.summary(modality: "AFTER_MARKET").kind, .directSale)
        XCTAssertEqual(Self.summary(modality: "LEILAO").kind, .auction)
        XCTAssertEqual(Self.summary(modality: nil).kind, .auction)
        XCTAssertEqual(Self.summary(modality: "SOMETHING_NEW").kind, .auction)
    }

    func testUrgencyFollowsTheDeadline() {
        func urgency(_ seconds: Int, endsAt: String? = "2026-10-15T14:12:00Z", modality: String = "LEILAO") -> Urgency {
            Self.summary(modality: modality, secondsToClose: seconds, endsAt: endsAt).urgency
        }
        XCTAssertEqual(urgency(0), .ended)
        XCTAssertEqual(urgency(-1), .ended, "a deadline that has passed, however it is reported")
        XCTAssertEqual(urgency(1), .hot)
        XCTAssertEqual(urgency(86_400), .hot)
        XCTAssertEqual(urgency(86_401), .normal)
        XCTAssertEqual(urgency(-1, endsAt: nil), .none)
        XCTAssertEqual(urgency(0, endsAt: nil), .none)
    }

    func testADirectSaleIsNeverHot() {
        XCTAssertEqual(Self.summary(modality: "AFTER_MARKET", secondsToClose: 3_600).urgency, .normal)
        XCTAssertEqual(Self.summary(modality: "AFTER_MARKET", secondsToClose: 86_400).urgency, .normal)
        XCTAssertEqual(Self.summary(modality: "AFTER_MARKET", secondsToClose: 0).urgency, .ended)
    }

    // MARK: tolerant decoding

    func testAMissingAcceptsProposalMeansNo() {
        XCTAssertFalse(Self.summary(acceptsProposal: nil).acceptsProposal)
        XCTAssertTrue(Self.summary(acceptsProposal: true).acceptsProposal)
    }

    func testALotWithoutOptionalFieldsStillDecodes() throws {
        let lot = try JSONDecoder().decode(LotSummary.self, from: Data(#"{"id": 7}"#.utf8))
        XCTAssertEqual(lot.id, 7)
        XCTAssertEqual(lot.title, "")
        XCTAssertEqual(lot.bidCount, 0)
        XCTAssertEqual(lot.secondsToClose, -1)
        XCTAssertNil(lot.currentPrice)
        XCTAssertFalse(lot.acceptsProposal)
    }

    func testTheDetailDecodesWithoutSyncedAtAndWithoutSpecs() throws {
        let json = #"{"id": 7, "title": "Casa"}"#
        let lot = try JSONDecoder().decode(LotDetail.self, from: Data(json.utf8))
        XCTAssertNil(lot.syncedAt)
        XCTAssertNil(lot.statusLabel)
        XCTAssertTrue(lot.specs.isEmpty)
        XCTAssertTrue(lot.images.isEmpty)
        XCTAssertFalse(lot.acceptsProposal)
        XCTAssertEqual(lot.secondsToClose, -1)
    }

    func testTheDetailReadsWhenThePriceWasRead() throws {
        let json = #"{"id": 7, "title": "Casa", "syncedAt": "2026-10-10T21:31:38.178751Z"}"#
        let lot = try JSONDecoder().decode(LotDetail.self, from: Data(json.utf8))
        XCTAssertEqual(lot.syncedAt, "2026-10-10T21:31:38.178751Z")
    }

    func testTheSentinelFieldsAreNeverDecoded() throws {
        let json = #"{"id": 7, "title": "Casa", "reservedPrice": 999999999999, "paymentTerms": "Preço de reserva: 999999999999"}"#
        let lot = try JSONDecoder().decode(LotDetail.self, from: Data(json.utf8))
        let mirror = Mirror(reflecting: lot).children.compactMap(\.label)
        XCTAssertFalse(mirror.contains("reservedPrice"))
        XCTAssertFalse(mirror.contains("paymentTerms"))
    }

    func testTheHomeResponseDecodesTheShelvesTheServerAssembled() throws {
        let json = """
        {"updatedAt": "2026-10-10T21:32:21.442815Z", "totalLots": 4697, "shelves": [
          {"id": "ending", "title": "Encerrando em breve", "subtitle": "Os próximos a fechar",
           "query": {"sort": "ending", "modality": "LEILAO"},
           "items": [{"id": 4724, "title": "HONDA CIVIC", "bidCount": 4, "secondsToClose": 2388}]},
          {"id": "real-estate", "title": "Imóveis", "query": {"sort": "popular", "category": "13", "endsWithin": 72}, "items": []}
        ]}
        """
        let home = try JSONDecoder().decode(HomeResponse.self, from: Data(json.utf8))
        XCTAssertEqual(home.totalLots, 4697)
        XCTAssertEqual(home.shelves.map(\.id), ["ending", "real-estate"])
        XCTAssertEqual(home.shelves[0].query.modality, "LEILAO")
        XCTAssertEqual(home.shelves[0].items.first?.id, 4724)
        XCTAssertEqual(home.shelves[1].query.category, "13")
        XCTAssertEqual(home.shelves[1].query.endsWithin, 72)
        XCTAssertNil(home.shelves[1].subtitle)
    }

    // MARK: query

    func testTheQueryCarriesEveryFilterAndTheSort() {
        let query = LotQuery(
            search: " moto ", category: "10", modality: "AFTER_MARKET", endsWithin: 72,
            minPrice: 1_000, maxPrice: 50_000, sort: .priceDescending, page: 2, size: 24)
        let items = Dictionary(uniqueKeysWithValues: query.queryItems.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["q"], "moto")
        XCTAssertEqual(items["category"], "10")
        XCTAssertEqual(items["modality"], "AFTER_MARKET")
        XCTAssertEqual(items["endsWithin"], "72")
        XCTAssertEqual(items["minPrice"], "1000")
        XCTAssertEqual(items["maxPrice"], "50000")
        XCTAssertEqual(items["sort"], "price_desc")
        XCTAssertEqual(items["page"], "2")
        XCTAssertEqual(items["size"], "24")
    }

    func testAnEmptyQuerySendsOnlySortAndPaging() {
        let names = LotQuery().queryItems.map(\.name)
        XCTAssertEqual(names, ["sort", "page", "size"])
        XCTAssertFalse(LotQuery(search: "   ").queryItems.contains { $0.name == "q" })
    }

    func testTheSixSortsAreTheOnesOfTheContract() {
        XCTAssertEqual(
            LotSort.allCases.map(\.rawValue),
            ["ending", "price_asc", "price_desc", "bids", "recent", "popular"])
        XCTAssertEqual(
            LotSort.allCases.map(\.label),
            ["Encerrando primeiro", "Menor preço", "Maior preço", "Mais lances", "Mais recentes", "Mais vistos"])
    }

    // MARK: tile

    func testAnAuctionTileCaptionsTheBids() {
        let tile = LotDisplay(Self.summary(bids: 13))
        XCTAssertEqual(tile.title, "Chevrolet Classic LS 2010/2011 Cinza")
        XCTAssertEqual(tile.caption, "13 lances")
        XCTAssertEqual(LotDisplay(Self.summary(bids: 0)).caption, "Sem lances")
        XCTAssertEqual(LotDisplay(Self.summary(bids: 1)).caption, "1 lance")
    }

    func testADirectSaleTileSaysNothingTwiceAndOffersTheProposal() {
        XCTAssertNil(LotDisplay(Self.summary(modality: "AFTER_MARKET", bids: 0)).caption)
        XCTAssertEqual(
            LotDisplay(Self.summary(modality: "AFTER_MARKET", bids: 0, acceptsProposal: true)).caption,
            "Aceita proposta")
        XCTAssertEqual(LotDisplay(Self.summary(modality: "AFTER_MARKET")).chip, .label("Venda direta"))
    }

    func testTheBadgeOnThePhotoOnlySpeaksOfTheExceptional() {
        XCTAssertEqual(LotDisplay(Self.summary(secondsToClose: 5 * 3_600 + 20 * 60)).chip, .time("5h 20min", hot: true))
        XCTAssertEqual(LotDisplay(Self.summary(secondsToClose: 4 * 86_400 + 15 * 3_600)).chip, .time("4d 15h", hot: false))
        XCTAssertEqual(LotDisplay(Self.summary(secondsToClose: 0)).chip, .label("Encerrado"))
        XCTAssertNil(LotDisplay(Self.summary(secondsToClose: -1, endsAt: nil)).chip)
        XCTAssertEqual(
            LotDisplay(Self.summary(modality: "AFTER_MARKET", secondsToClose: 0)).chip, .label("Encerrado"))
    }

    func testOnlyAHotLotIsPaintedVermilion() {
        XCTAssertTrue(LotDisplay(Self.summary(secondsToClose: 3_600)).isHot)
        XCTAssertFalse(LotDisplay(Self.summary(secondsToClose: 3 * 86_400)).isHot)
        XCTAssertFalse(LotDisplay(Self.summary(modality: "AFTER_MARKET", secondsToClose: 3_600)).isHot)
    }

    func testTheTilePricesWithTheShortForm() {
        XCTAssertEqual(LotDisplay(Self.summary(price: 12_510_000)).price, "R$\u{00A0}12,5\u{00A0}mi")
        XCTAssertEqual(LotDisplay(Self.summary(price: nil)).price, "Sob consulta")
        XCTAssertTrue(LotDisplay(Self.summary(price: nil)).priceIsRequest)
    }

    func testTheRealPlaceOfTheItemComesFromTheTitleOnly() {
        let titled = Self.summary(title: "Casa 78m² com Terreno 300m² | Rosário Do Sul-RS | Vila Nova")
        XCTAssertEqual(LotDisplay(titled).place, "Rosário Do Sul-RS")
        XCTAssertNil(LotDisplay(Self.summary()).place)
    }

    func testTheTileIsOneSpokenSentence() {
        let auction = LotDisplay(Self.summary(secondsToClose: 4 * 86_400 + 15 * 3_600, price: 81_000, bids: 13))
        XCTAssertEqual(
            auction.accessibilityLabel,
            "Chevrolet Classic LS 2010/2011 Cinza, R$\u{00A0}81.000, 13 lances, encerra em 4 dias e 15 horas")

        let direct = LotDisplay(Self.summary(title: "TOURO NELORE - X1566", modality: "AFTER_MARKET", secondsToClose: 80 * 86_400, price: 16_000))
        XCTAssertEqual(
            direct.accessibilityLabel,
            "Touro Nelore - X1566, R$\u{00A0}16.000, venda direta, encerra em 80 dias")

        let ended = LotDisplay(Self.summary(secondsToClose: 0, price: 4_100, bids: 7))
        XCTAssertTrue(ended.accessibilityLabel.hasSuffix("7 lances, encerrado"))

        let undated = LotDisplay(Self.summary(secondsToClose: -1, endsAt: nil, price: 4_033.8, bids: 0))
        XCTAssertTrue(undated.accessibilityLabel.hasSuffix("Sem lances"))
    }

    func testTheHeartNamesTheLotItActsOn() {
        let tile = LotDisplay(Self.summary())
        XCTAssertEqual(tile.heartLabel(isOn: false), "Favoritar Chevrolet Classic LS 2010/2011 Cinza")
        XCTAssertEqual(tile.heartLabel(isOn: true), "Remover dos favoritos: Chevrolet Classic LS 2010/2011 Cinza")
    }

    func testTheGridDropsToOneColumnFromLargeText() {
        XCTAssertEqual(Measure.gridColumns(width: 390, typeSize: .large), 2)
        XCTAssertEqual(Measure.gridColumns(width: 390, typeSize: .xxLarge), 2)
        XCTAssertEqual(Measure.gridColumns(width: 390, typeSize: .xxxLarge), 1)
        XCTAssertEqual(Measure.gridColumns(width: 390, typeSize: .accessibility2), 1)
        XCTAssertEqual(Measure.gridColumns(width: 600, typeSize: .large), 3)
        XCTAssertEqual(Measure.gridColumns(width: 839, typeSize: .large), 3)
        XCTAssertEqual(Measure.gridColumns(width: 840, typeSize: .large), 4)
    }

    func testEveryCategoryOfTheCatalogueHasAShortLabelAndAnIcon() {
        XCTAssertEqual(Categories.style(for: "Imóveis"), CategoryStyle(label: "Imóveis", symbol: "building.2"))
        XCTAssertEqual(Categories.style(for: "Caminhões & Ônibus").label, "Caminhões")
        XCTAssertEqual(Categories.style(for: "Partes e Peças ").label, "Partes e peças", "the API pads this name")
        XCTAssertEqual(Categories.style(for: "Sucatas , Materiais & Resíduos").label, "Sucatas")
        XCTAssertEqual(Categories.style(for: "Algo Novo "), CategoryStyle(label: "Algo Novo", symbol: "tag"))
    }
}
