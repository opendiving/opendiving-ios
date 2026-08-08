import Foundation

enum AuthAPI {
    static func signIn(username: String, password: String) async throws -> AuthToken {
        let body = "username=\(username)&password=\(password)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let token: AuthToken = try await APIClient.shared.request(
            path: "login",
            method: "POST",
            body: Data(body.utf8),
            contentType: "application/x-www-form-urlencoded",
            authenticated: false
        )
        KeychainHelper.save(token.accessToken)
        return token
    }

    static func signUp(name: String, username: String, email: String, password: String) async throws -> User {
        let payload: [String: String] = [
            "name": name, "username": username, "email": email, "password": password,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await APIClient.shared.request(
            path: "user", method: "POST", body: body, authenticated: false
        )
    }

    static func currentUser() async throws -> User {
        try await APIClient.shared.request(path: "user/")
    }
}
