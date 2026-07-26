import Foundation

enum APIError: LocalizedError {
    case server(status: Int, message: String)
    case decoding
    case network(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .server(_, let message): return message
        case .decoding: return "The server sent an unexpected response."
        case .network(let error): return error.localizedDescription
        case .unauthorized: return "Your session expired. Please log in again."
        }
    }
}

/// Talks to the Allergen Scanner backend. Holds the current session token in
/// memory (persisted separately via KeychainHelper) and attaches it as a
/// bearer token to every authenticated request.
@Observable
final class APIClient {
    static let shared = APIClient()

    // Render free tier "spins down" after inactivity; first request after a
    // period of idle can take 30-60s to cold-start, hence the long timeout.
    private static let baseURL = URL(string: "https://allergen-scanner-api.onrender.com")!

    var session: AuthSession? {
        didSet {
            if let session {
                KeychainHelper.save(session)
            } else {
                KeychainHelper.clear()
            }
        }
    }

    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.urlSession = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.session = KeychainHelper.load()
    }

    // MARK: - Auth

    func createRestaurant(name: String, adminPin: String) async throws -> AuthSession {
        try await post("/restaurants", body: ["name": name, "admin_pin": adminPin], authenticated: false)
    }

    func joinRestaurant(joinCode: String) async throws -> AuthSession {
        try await post("/restaurants/join", body: ["join_code": joinCode], authenticated: false)
    }

    func adminLogin(joinCode: String, adminPin: String) async throws -> AuthSession {
        try await post("/auth/admin-login", body: ["join_code": joinCode, "admin_pin": adminPin], authenticated: false)
    }

    func logOut() {
        session = nil
    }

    // MARK: - Allergens

    func fetchAllergens() async throws -> [Allergen] {
        try await get("/allergens")
    }

    func createAllergen(name: String, description: String?) async throws -> Allergen {
        try await post("/allergens", body: ["name": name, "description": description as Any])
    }

    // MARK: - Food items

    func fetchFoodItems() async throws -> [FoodItem] {
        try await get("/food-items")
    }

    func createFoodItem(name: String, description: String?, category: String?, allergenIds: [Int]) async throws -> FoodItem {
        try await post("/food-items", body: [
            "name": name,
            "description": description as Any,
            "category": category as Any,
            "allergen_ids": allergenIds,
        ])
    }

    func deleteFoodItem(id: Int) async throws {
        try await delete("/food-items/\(id)")
    }

    // MARK: - Recipes

    func fetchRecipes() async throws -> [Recipe] {
        try await get("/recipes")
    }

    func createRecipe(name: String, description: String?, foodItemIds: [Int]) async throws -> Recipe {
        try await post("/recipes", body: [
            "name": name,
            "description": description as Any,
            "food_item_ids": foodItemIds,
        ])
    }

    func deleteRecipe(id: Int) async throws {
        try await delete("/recipes/\(id)")
    }

    // MARK: - Scan

    func scanText(lines: [String]) async throws -> ScanResult {
        try await post("/scan/text", body: ["text_lines": lines])
    }

    // MARK: - Core request plumbing

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "GET", body: nil)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], authenticated: Bool = true) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: sanitize(body))
        return try await request(path, method: "POST", body: data, authenticated: authenticated)
    }

    private func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(path, method: "DELETE", body: nil)
    }

    private func sanitize(_ body: [String: Any]) -> [String: Any] {
        // JSONSerialization can't handle Swift's `nil` boxed as `Any`; drop those keys.
        body.filter { !($0.value is NSNull) && !isNilAny($0.value) }
    }

    private func isNilAny(_ value: Any) -> Bool {
        if case Optional<Any>.none = value { return true }
        return false
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        body: Data?,
        authenticated: Bool = true
    ) async throws -> T {
        var urlRequest = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body

        if authenticated {
            guard let token = session?.token else { throw APIError.unauthorized }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.decoding
        }

        if httpResponse.statusCode == 401 {
            session = nil
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorDetail.self, from: data))?.detail
                ?? "Request failed (\(httpResponse.statusCode))"
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

private struct ErrorDetail: Decodable {
    let detail: String
}

private struct EmptyResponse: Decodable {}
