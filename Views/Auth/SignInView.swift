import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "water.waves")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("OpenDiving")
                    .font(.largeTitle.bold())

                TextField("Username or email", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage = auth.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button {
                    Task {
                        isSubmitting = true
                        await auth.signIn(username: username, password: password)
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Sign In").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isSubmitting)
            }
            .padding()
        }
    }
}
