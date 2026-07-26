import Foundation

enum UserRole: String, Codable {
    case admin
    case staff
}

struct Allergen: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
}

struct FoodItem: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var category: String?
    var imagePath: String?
    var allergens: [Allergen]

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, allergens
        case imagePath = "image_path"
    }
}

struct Recipe: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var items: [FoodItem]
    var allergens: [RecipeAllergenSummary]
}

struct AuthSession: Codable {
    let token: String
    let restaurantId: Int
    let restaurantName: String
    let joinCode: String?
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case token
        case restaurantId = "restaurant_id"
        case restaurantName = "restaurant_name"
        case joinCode = "join_code"
        case role
    }
}

struct AllergenRef: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct ScanResult: Codable {
    let detectedAllergens: [AllergenRef]
    let allAllergens: [AllergenRef]

    enum CodingKeys: String, CodingKey {
        case detectedAllergens = "detected_allergens"
        case allAllergens = "all_allergens"
    }
}

struct RecipeAllergenSummary: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
    let items: [String]
}
