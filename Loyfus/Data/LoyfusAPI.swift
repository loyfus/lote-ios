import Foundation

enum APIError: LocalizedError {
    case badURL
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "URL inválida"
        case .http(let code): return "Servidor respondeu \(code)"
        case .empty: return "Resposta vazia"
        }
    }
}

// A failed request and an empty result are different facts, and the UI has to say
// so: one needs a retry, the other needs a different filter.
enum LoadFailure {
    case notFound
    case offline(String)

    static func classify(_ error: Error) -> LoadFailure {
        if case APIError.http(404) = error { return .notFound }
        if case APIError.http(let code) = error, code >= 500 {
            return .offline("O servidor do leilão respondeu com erro. Tente de novo em instantes.")
        }
        if let url = error as? URLError, url.code == .notConnectedToInternet {
            return .offline("Você está sem conexão. Os dados serão recarregados assim que a rede voltar.")
        }
        return .offline("A conexão com o servidor do leilão falhou. Seus dados não foram alterados.")
    }
}

struct LoyfusAPI {
    let baseURL: URL
    let deviceId: String

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func get<T: Decodable>(_ path: String, items: [URLQueryItem] = []) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false
        ) else { throw APIError.badURL }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw APIError.badURL }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.empty }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post(_ path: String) async throws {
        try await send("POST", path)
    }

    func delete(_ path: String) async throws {
        try await send("DELETE", path)
    }

    private func send(_ method: String, _ path: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

struct LoyfusRepository {
    let api: LoyfusAPI

    func home() async throws -> HomeResponse { try await api.get("api/v1/home") }

    func categories() async throws -> [Category] { try await api.get("api/v1/categories") }

    func lots(_ query: LotQuery) async throws -> LotPage {
        try await api.get("api/v1/lots", items: query.queryItems)
    }

    func lot(_ id: Long) async throws -> LotDetail { try await api.get("api/v1/lots/\(id)") }

    /// 60 is the most the API serves in one page.
    func favourites(page: Int = 0) async throws -> LotPage {
        try await api.get("api/v1/favourites", items: [
            .init(name: "page", value: "\(page)"), .init(name: "size", value: "60"),
        ])
    }

    func addFavourite(_ id: Long) async throws { try await api.post("api/v1/favourites/\(id)") }

    func removeFavourite(_ id: Long) async throws { try await api.delete("api/v1/favourites/\(id)") }
}
