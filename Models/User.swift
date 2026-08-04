import Foundation

struct User: Codable, Identifiable {
    let uuid: UUID
    let name: String
    let username: String
    let email: String
    let profileImageUrl: String

    /// `Identifiable` conformance - the API's opaque public id for this user.
    var id: UUID { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, username, email
        case profileImageUrl = "profile_image_url"
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
