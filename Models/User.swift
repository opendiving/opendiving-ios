import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let profileImageUrl: String
    let tierId: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, username, email
        case profileImageUrl = "profile_image_url"
        case tierId = "tier_id"
    }
}

struct AuthToken: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}
