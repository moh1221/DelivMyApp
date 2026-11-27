import DelivMyCore
import Observation
import SwiftUI

@main
struct DelivMyApp: App {
    @State private var account = AccountModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if let client = account.client {
                    if let session = account.session {
                        SignedInView(client: client, session: session, account: account)
                            .id(session.userID)
                    } else {
                        LoginView(client: client, account: account)
                    }
                } else {
                    ContentUnavailableView(
                        "Server configuration unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(account.configurationError ?? "Check the DelivMy server configuration.")
                    )
                }
            }
            .alert("DelivMy", isPresented: Binding(
                get: { account.notice != nil },
                set: { if !$0 { account.notice = nil } }
            )) {
                Button("OK", role: .cancel) { account.notice = nil }
            } message: {
                Text(account.notice ?? "")
            }
        }
    }
}

@MainActor
@Observable
final class AccountModel {
    let client: APIClient?
    let configurationError: String?
    private(set) var session: AuthSession?
    private(set) var signingIn = false
    private(set) var signingOut = false
    private(set) var changeID = UUID()
    var notice: String?

    init() {
        #if DEBUG
        let debugURL = ProcessInfo.processInfo.environment["DELIVMY_API_BASE_URL"]
        let allowInsecureLoopback = true
        #else
        let debugURL: String? = nil
        let allowInsecureLoopback = false
        #endif
        let configured = debugURL ?? (Bundle.main.object(forInfoDictionaryKey: "DelivMyAPIBaseURL") as? String)
        do {
            let url: URL
            if let configured, !configured.isEmpty {
                guard let parsed = URL(string: configured) else { throw APIError.invalidServerURL }
                url = parsed
            } else {
                url = APIClient.productionURL
            }
            client = try APIClient(baseURL: url, allowInsecureLoopback: allowInsecureLoopback)
            configurationError = nil
        } catch {
            client = nil
            configurationError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        guard let client, !signingIn, session == nil else { return }
        signingIn = true
        defer { signingIn = false }
        do {
            session = try await client.login(email: email, password: password)
        } catch {
            _ = present(error)
        }
    }

    func signOut() async {
        guard let client, let session, !signingOut else { return }
        signingOut = true
        defer { signingOut = false }
        // Discard local session state even when revocation can't reach the server.
        do {
            try await client.logout(session: session)
            self.session = nil
        } catch {
            self.session = nil
            if (error as? APIError) != .sessionExpired {
                notice = "You’re signed out on this device. The server didn’t confirm that the session was revoked."
            }
        }
    }

    func refreshLists() { changeID = UUID() }

    // Return a safe display message, or nil when there is nothing to display locally.
    func failureMessage(_ error: Error) -> String? {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return nil }
        if (error as? APIError) == .sessionExpired {
            session = nil
            notice = APIError.sessionExpired.localizedDescription
            return nil
        }
        if error is URLError {
            return "Couldn’t connect to DelivMy. Check your connection and try again."
        }
        return error.localizedDescription
    }

    @discardableResult
    func present(_ error: Error) -> Bool {
        guard let text = failureMessage(error) else { return false }
        notice = text
        return true
    }
}

private struct LoginView: View {
    let client: APIClient
    let account: AccountModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("loginEmail")
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .onSubmit(submit)
                        .accessibilityIdentifier("loginPassword")
                }
                Section {
                    Button(action: submit) {
                        if account.signingIn {
                            ProgressView("Signing in…")
                        } else {
                            Text("Sign in")
                        }
                    }
                    .disabled(account.signingIn || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    .accessibilityIdentifier("loginSubmit")
                    Link("Create an account", destination: client.signUpURL)
                }
            }
            .navigationTitle("DelivMy")
        }
    }

    private func submit() {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty, !account.signingIn else { return }
        let submittedPassword = password
        password = ""
        Task { await account.signIn(email: normalizedEmail, password: submittedPassword) }
    }
}

private struct SignedInView: View {
    let client: APIClient
    let session: AuthSession
    let account: AccountModel
    @State private var showSignOut = false

    var body: some View {
        TabView {
            NearbyView(client: client, session: session, account: account)
                .tabItem { Label("Nearby", systemImage: "map") }
            RequestList(client: client, session: session, account: account, kind: .mine)
                .tabItem { Label("My Requests", systemImage: "list.bullet.rectangle") }
            RequestList(client: client, session: session, account: account, kind: .deliveries)
                .tabItem { Label("My Deliveries", systemImage: "shippingbox") }
            NavigationStack {
                Form {
                    Button("Sign out", role: .destructive) { showSignOut = true }
                        .disabled(account.signingOut)
                }
                .navigationTitle("Account")
                .confirmationDialog("Sign out of DelivMy?", isPresented: $showSignOut, titleVisibility: .visible) {
                    Button("Sign out", role: .destructive) {
                        Task { await account.signOut() }
                    }
                }
            }
            .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
