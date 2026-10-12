import Foundation

typealias Long = Int64

// The API omits null values, so a field that is null arrives as a missing key. Every
// model below is decoded field by field and treats missing as empty: a strict
// decode would take a whole screen down over one absent optional.

/// A lot as a list shows it. Codable only so that the compiler writes the coding keys;
/// the decoder below is the one that matters.
struct LotSummary: Codable, Identifiable, Hashable, LotTimeline {
    let id: Long
    let sourceCode: String?
    let externalId: String?
    let lotNumber: String?
    let title: String
    let categoryName: String?
    let categoryExternalId: String?
    let modality: String?
    let modalityLabel: String?
    let organizer: String?
    let currentPrice: Double?
    let initialPrice: Double?
    let minimumIncrement: Double?
    let currency: String?
    let bidCount: Int
    let status: String?
    let statusLabel: String?
    let endingSoon: Bool
    let endsAt: String?
    let secondsToClose: Int
    let primaryImageUrl: String?
    let city: String?
    let stateCode: String?
    let webUrl: String?
    let acceptsProposal: Bool
}

extension LotSummary {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Long.self, forKey: .id)
        sourceCode = c.value(.sourceCode)
        externalId = c.value(.externalId)
        lotNumber = c.value(.lotNumber)
        title = c.value(.title, "")
        categoryName = c.value(.categoryName)
        categoryExternalId = c.value(.categoryExternalId)
        modality = c.value(.modality)
        modalityLabel = c.value(.modalityLabel)
        organizer = c.value(.organizer)
        currentPrice = c.value(.currentPrice)
        initialPrice = c.value(.initialPrice)
        minimumIncrement = c.value(.minimumIncrement)
        currency = c.value(.currency)
        bidCount = c.value(.bidCount, 0)
        status = c.value(.status)
        statusLabel = c.value(.statusLabel)
        endingSoon = c.value(.endingSoon, false)
        endsAt = c.value(.endsAt)
        secondsToClose = c.value(.secondsToClose, -1)
        primaryImageUrl = c.value(.primaryImageUrl)
        city = c.value(.city)
        stateCode = c.value(.stateCode)
        webUrl = c.value(.webUrl)
        acceptsProposal = c.value(.acceptsProposal, false)
    }
}

/// A lot as the detail screen shows it.
struct LotDetail: Decodable, Identifiable, LotTimeline {
    let id: Long
    let externalId: String?
    let sourceCode: String?
    let sourceName: String?
    let lotNumber: String?
    let title: String
    let description: String?
    let categoryName: String?
    let categoryExternalId: String?
    let modality: String?
    let modalityLabel: String?
    let specs: [String: String]
    let currentPrice: Double?
    let initialPrice: Double?
    let estimatedPrice: Double?
    let minimumIncrement: Double?
    let currency: String?
    let bidCount: Int
    let bidderCount: Int
    let visitCount: Int
    let status: String?
    let statusLabel: String?
    let endingSoon: Bool
    let sold: Bool
    let reserved: Bool
    let acceptsProposal: Bool
    let isFavourite: Bool
    let conditionLabel: String?
    let commercialCondition: String?
    let sellerName: String?
    let sellerCity: String?
    let city: String?
    let stateCode: String?
    let startsAt: String?
    let endsAt: String?
    let publishedAt: String?
    /// When the crawler last read the values: the price has an age, and the screen says it.
    let syncedAt: String?
    let secondsToClose: Int
    let images: [String]
    let webUrl: String?
    let auction: AuctionInfo?

    // `reservedPrice` and `paymentTerms` are deliberately not decoded: the catalogue
    // stores the sentinel 999999999999 in them, and a field that is never read can
    // never be displayed by mistake.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Long.self, forKey: .id)
        externalId = c.value(.externalId)
        sourceCode = c.value(.sourceCode)
        sourceName = c.value(.sourceName)
        lotNumber = c.value(.lotNumber)
        title = try c.decode(String.self, forKey: .title)
        description = c.value(.description)
        categoryName = c.value(.categoryName)
        categoryExternalId = c.value(.categoryExternalId)
        modality = c.value(.modality)
        modalityLabel = c.value(.modalityLabel)
        specs = c.value(.specs, [:])
        currentPrice = c.value(.currentPrice)
        initialPrice = c.value(.initialPrice)
        estimatedPrice = c.value(.estimatedPrice)
        minimumIncrement = c.value(.minimumIncrement)
        currency = c.value(.currency)
        bidCount = c.value(.bidCount, 0)
        bidderCount = c.value(.bidderCount, 0)
        visitCount = c.value(.visitCount, 0)
        status = c.value(.status)
        statusLabel = c.value(.statusLabel)
        endingSoon = c.value(.endingSoon, false)
        sold = c.value(.sold, false)
        reserved = c.value(.reserved, false)
        acceptsProposal = c.value(.acceptsProposal, false)
        isFavourite = c.value(.isFavourite, false)
        conditionLabel = c.value(.conditionLabel)
        commercialCondition = c.value(.commercialCondition)
        sellerName = c.value(.sellerName)
        sellerCity = c.value(.sellerCity)
        city = c.value(.city)
        stateCode = c.value(.stateCode)
        startsAt = c.value(.startsAt)
        endsAt = c.value(.endsAt)
        publishedAt = c.value(.publishedAt)
        syncedAt = c.value(.syncedAt)
        secondsToClose = c.value(.secondsToClose, -1)
        images = c.value(.images, [])
        webUrl = c.value(.webUrl)
        auction = c.value(.auction)
    }

    private enum CodingKeys: String, CodingKey {
        case id, externalId, sourceCode, sourceName, lotNumber, title, description
        case categoryName, categoryExternalId, modality, modalityLabel, specs
        case currentPrice, initialPrice, estimatedPrice, minimumIncrement, currency
        case bidCount, bidderCount, visitCount, status, statusLabel, endingSoon
        case sold, reserved, acceptsProposal, isFavourite, conditionLabel, commercialCondition
        case sellerName, sellerCity, city, stateCode, startsAt, endsAt, publishedAt, syncedAt
        case secondsToClose, images, webUrl, auction
    }
}

extension KeyedDecodingContainer {
    /// Reads an optional field, treating a missing key and an explicit null alike.
    func value<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        value(key) ?? fallback
    }
}

struct AuctionInfo: Decodable {
    let title: String?
    let description: String?
    let modality: String?
    let organizer: String?
    let organizerLogoUrl: String?
    let managerName: String?
    let contactEmail: String?
    let contactPhone: String?
    let startsAt: String?
    let endsAt: String?
    let webUrl: String?
    let noticeUrl: String?
}

struct LotPage: Decodable {
    let items: [LotSummary]
    let page: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrevious: Bool
}

struct Category: Decodable, Identifiable, Hashable {
    let externalId: String
    let name: String
    let slug: String?
    let level: Int
    let sourceCount: Int
    let availableCount: Int

    var id: String { externalId }
}

/// `GET /api/v1/home`: the shelves are assembled on the server.
struct HomeResponse: Decodable {
    let updatedAt: String?
    let totalLots: Int
    /// The nearest window (24, 72 or 168 h) that still has auctions; nil when
    /// nothing closes within a week, so the card is simply not drawn.
    let closing: ClosingWindow?
    /// How many lots take an offer below the asking price.
    let acceptsProposal: Int
    let shelves: [Shelf]

    /// The server decides the window so both clients say the same true thing.
    struct ClosingWindow: Decodable {
        let count: Int
        let withinHours: Int
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt, totalLots, closing, acceptsProposal, shelves
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = c.value(.updatedAt)
        totalLots = c.value(.totalLots, 0)
        closing = c.value(.closing)
        acceptsProposal = c.value(.acceptsProposal, 0)
        shelves = c.value(.shelves, [])
    }
}

struct Shelf: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    /// The query that "Ver todos" hands to Explore.
    let query: ShelfQuery
    let items: [LotSummary]

    private enum CodingKeys: String, CodingKey { case id, title, subtitle, query, items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = c.value(.title, "")
        subtitle = c.value(.subtitle)
        query = c.value(.query, ShelfQuery())
        items = c.value(.items, [])
    }
}

struct ShelfQuery: Decodable, Hashable {
    var sort: String = LotSort.ending.rawValue
    var category: String?
    var modality: String?
    var endsWithin: Int?
    var acceptsProposal: Bool?

    private enum CodingKeys: String, CodingKey {
        case sort, category, modality, endsWithin, acceptsProposal
    }

    init() {}

    /// Built by hand on the client: what a shelf's "Ver todos" hands to Explore.
    init(sort: String = LotSort.ending.rawValue,
         category: String? = nil,
         modality: String? = nil,
         endsWithin: Int? = nil,
         acceptsProposal: Bool? = nil) {
        self.sort = sort
        self.category = category
        self.modality = modality
        self.endsWithin = endsWithin
        self.acceptsProposal = acceptsProposal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sort = c.value(.sort, LotSort.ending.rawValue)
        category = c.value(.category)
        modality = c.value(.modality)
        endsWithin = c.value(.endsWithin)
        acceptsProposal = c.value(.acceptsProposal)
    }
}

/// The six orderings the API offers, in the order the menu lists them.
enum LotSort: String, CaseIterable, Identifiable {
    case ending
    case priceAscending = "price_asc"
    case priceDescending = "price_desc"
    case bids
    case recent
    case popular

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ending: return "Encerrando primeiro"
        case .priceAscending: return "Menor preço"
        case .priceDescending: return "Maior preço"
        case .bids: return "Mais lances"
        case .recent: return "Mais recentes"
        case .popular: return "Mais vistos"
        }
    }
}

/// What a lot is, as far as the API's `modality` field tells: a sale with bids, or a
/// post-auction direct sale (`AFTER_MARKET`).
enum LotModality: String, CaseIterable {
    case auction = "LEILAO"
    case directSale = "AFTER_MARKET"

    var label: String {
        switch self {
        case .auction: return "Leilão"
        case .directSale: return "Venda direta"
        }
    }
}

struct LotQuery: Equatable {
    var search: String?
    var category: String?
    var modality: String?
    /// Hours: the lot closes within this many.
    var endsWithin: Int?
    /// Only lots that take an offer below the asking price.
    var acceptsProposal: Bool?
    var minPrice: Int?
    var maxPrice: Int?
    var sort: LotSort = .ending
    var page = 0
    var size = 24

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let search = search?.trimmingCharacters(in: .whitespaces), !search.isEmpty {
            items.append(.init(name: "q", value: search))
        }
        if let category { items.append(.init(name: "category", value: category)) }
        if let modality { items.append(.init(name: "modality", value: modality)) }
        if let endsWithin { items.append(.init(name: "endsWithin", value: String(endsWithin))) }
        if let acceptsProposal { items.append(.init(name: "acceptsProposal", value: String(acceptsProposal))) }
        if let minPrice { items.append(.init(name: "minPrice", value: String(minPrice))) }
        if let maxPrice { items.append(.init(name: "maxPrice", value: String(maxPrice))) }
        items.append(.init(name: "sort", value: sort.rawValue))
        items.append(.init(name: "page", value: String(page)))
        items.append(.init(name: "size", value: String(size)))
        return items
    }
}
