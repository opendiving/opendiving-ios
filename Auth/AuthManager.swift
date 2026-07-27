import Foundation

@MainActor
@Observable
final class AuthManager {
    var currentUser: User?
    var isLoading = true
    var errorMessage: String?

    var isAuthenticated: Bool { currentUser != nil }

    func bootstrap() async {
        guard KeychainHelper.read() != nil else {
            isLoading = false
            return
        }
        await refreshCurrentUser()
        isLoading = false
    }

    func signIn(username: String, password: String) async {
        errorMessage = nil
        do {
            _ = try await AuthAPI.signIn(username: username, password: password)
            await refreshCurrentUser()
        } catch {
            errorMessage = (error as? APIError)?.message ?? "Something went wrong."
        }
    }

    func signOut() {
        KeychainHelper.delete()
        currentUser = nil
    }

    private func refreshCurrentUser() async {
        do {
            currentUser = try await AuthAPI.currentUser()
        } catch {
            KeychainHelper.delete()
            currentUser = nil
        }
    }
}
