//
//  AccountScreens.swift
//  Maqr
//
//  The Me tab, signing in, and deleting an account.
//

import AuthenticationServices
import CryptoKit
import MaqrDashboard
import SwiftUI

// MARK: - Me

struct MeScreen: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @State private var store: AccountStore
    @State private var mine: MyExperiencesStore
    @State private var deleting = false
    @State private var confirmingSignOut = false

    init(dashboard: Dashboard) {
        _store = State(initialValue: AccountStore(dashboard: dashboard))
        _mine = State(initialValue: MyExperiencesStore(dashboard: dashboard))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    InitialAvatar(name: store.name, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.name).font(.title3.weight(.bold)).lineLimit(1)
                        HStack(spacing: 6) {
                            Text(store.email).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            if let verified = store.isVerified {
                                StatusBadge(text: verified ? String(localized: "Confirmed") : String(localized: "Unconfirmed"),
                                            tone: verified ? .live : .muted)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if store.isVerified == false {
                Section {
                    NoticeCard(title: String(localized: "Confirm your email"), message: store.verificationNotice, kind: .alert)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    Button(store.resendLabel) { Task { await store.resendVerification() } }
                        .disabled(store.resend == .sending || store.cooldown > 0)
                        .contentTransition(.numericText())
                }
            }

            Section {
                NavigationLink(value: Route.events) {
                    LabeledContent { Text(mine.experiences.value.map { "\($0.count)" } ?? "") } label: {
                        Label("Your designs", systemImage: "square.stack")
                    }
                }
                NavigationLink(value: Route.billing) {
                    LabeledContent { Text("Plans and receipts") } label: { Label("Plan & billing", systemImage: "creditcard") }
                }
                Button { model.tab = .explore } label: {
                    LabeledContent { Text("Browse everything") } label: { Label("Explore", systemImage: "safari") }
                }
                .foregroundStyle(.primary)
                Link(destination: model.dashboard.webURL("/")) {
                    LabeledContent { Text("The main site") } label: { Label("maQR home", systemImage: "globe") }
                }
                .foregroundStyle(.primary)
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                Button("Sign out") { confirmingSignOut = true }
                    .disabled(store.isSigningOut)
            } footer: {
                Text("Signing out ends this session and removes what this phone saved for your account.")
            }

            Section {
                Button("Delete my account", role: .destructive) { deleting = true }
            } header: {
                Text("Danger zone")
            } footer: {
                Text("Permanent. Your experiences, designs and scan history go with it, and printed codes stop working.")
            }
        }
        .navigationTitle("Me")
        .refreshable { await store.load() }
        .confirmationDialog("Sign out of maQR?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
        }
        .sheet(isPresented: $deleting) {
            DeleteAccountSheet(dashboard: model.dashboard)
        }
        .task {
            async let account: Void = store.load()
            async let experiences: Void = mine.load()
            _ = await (account, experiences)
        }
    }
}

// MARK: - Signing in

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let request: SignInRequest
    @State private var store: SignInStore
    @State private var nonce = ""
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    init(dashboard: Dashboard, request: SignInRequest) {
        self.request = request
        _store = State(initialValue: SignInStore(dashboard: dashboard, stage: request.stage, designTitle: request.designTitle))
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, value: store.stage == .choices)
                        Text(store.title).font(.title2.weight(.bold))
                        Text(store.subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if let note = store.note {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }

                    appleButton

                    if store.stage == .choices {
                        Button { withAnimation(.snappy) { store.stage = .create } } label: {
                            Label("Continue with email", systemImage: "envelope").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                            Button("Sign in") { withAnimation(.snappy) { store.stage = .signIn } }.fontWeight(.semibold)
                        }
                        .font(.footnote)
                        Text("Nothing is posted publicly until you choose to share it.")
                            .font(.footnote).foregroundStyle(.tertiary)
                    } else {
                        emailForm
                    }

                    if let error = store.error {
                        Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .padding()
                .animation(.snappy, value: store.stage)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.isBusy)
        .sensoryFeedback(.error, trigger: store.error)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            nonce = UUID().uuidString
            request.requestedScopes = [.fullName, .email]
            request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else { return }
                let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                Task {
                    if await store.signInWithApple(idToken: token, authCode: code, nonce: nonce, name: name) { finish() }
                }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled {
                    store.appleFailed(error.localizedDescription)
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .id(colorScheme)
        .frame(height: 50)
        .clipShape(Capsule())
        .disabled(store.isBusy)
    }

    private var emailForm: some View {
        @Bindable var store = store
        return VStack(spacing: 12) {
            HStack {
                Rectangle().fill(.separator).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(.secondary)
                Rectangle().fill(.separator).frame(height: 1)
            }
            VStack(spacing: 0) {
                if store.isCreating {
                    TextField("Your name", text: $store.name)
                        .textContentType(.name)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .padding()
                    Divider()
                }
                TextField("you@example.com", text: $store.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .padding()
                Divider()
                SecureField(store.isCreating ? "Choose a password" : "Your password", text: $store.password)
                    .textContentType(store.isCreating ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .padding()
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onSubmit {
                switch focus {
                case .name: focus = .email
                case .email: focus = .password
                default: Task { await submit() }
                }
            }

            Button { Task { await submit() } } label: {
                ZStack {
                    Text(store.submitLabel).opacity(store.isBusy ? 0 : 1)
                    if store.isBusy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!store.canSubmit)

            HStack(spacing: 4) {
                Text(store.switchPrompt)
                Button(store.switchAction) { withAnimation(.snappy) { store.switchMode() } }.fontWeight(.semibold)
            }
            .font(.footnote)
        }
        .onAppear { focus = store.isCreating ? .name : .email }
    }

    private func submit() async {
        focus = nil
        if await store.submit() { finish() }
    }

    private func finish() {
        dismiss()
        request.onSignedIn()
    }
}

// MARK: - Deleting the account

struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: DeleteAccountStore

    init(dashboard: Dashboard) {
        _store = State(initialValue: DeleteAccountStore(dashboard: dashboard))
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                if store.stage != .done {
                    Section {
                        Text("This cannot be undone, and there is no way for us to put it back.")
                            .foregroundStyle(.secondary)
                    }
                }
                switch store.stage {
                case .impact:
                    if store.impact == nil && store.failure == nil {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    if let impact = store.impact {
                        Section {
                            NoticeCard(title: String(localized: "What gets deleted"), message: store.whatGoes, kind: .alert)
                            if let collaborators = store.collaboratorsNotice {
                                NoticeCard(title: String(localized: "People you shared with lose access"), message: collaborators, kind: .alert)
                            }
                            if impact.hasSubscription {
                                NoticeCard(title: String(localized: "Your subscription is cancelled too"),
                                           message: String(localized: "It stops renewing as part of this. You are not charged again."))
                            }
                            NoticeCard(title: String(localized: "What we keep"),
                                       message: String(localized: "Records of payments you have made. We are required to keep those for tax and chargebacks — they are stripped of your name and address."))
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        Section {
                            Button("Continue", role: .destructive) { withAnimation { store.proceedToIdentify() } }
                            Button("Keep my account") { dismiss() }
                        }
                    }
                case .identify:
                    if let impact = store.impact {
                        if impact.requiresPassword {
                            Section("Your password") {
                                SecureField("Enter your password", text: $store.password).textContentType(.password)
                            }
                        }
                        if impact.requiresAppleReauth {
                            Section {
                                NoticeCard(title: String(localized: "Signed in with Apple"),
                                           message: String(localized: "Deleting an Apple-only account needs you to confirm with Apple, which isn't available here yet."))
                            }
                        }
                        Section {
                            TextField("Why you’re leaving", text: $store.reason, axis: .vertical).lineLimit(2...4)
                        } header: {
                            Text("Anything you want to tell us? (optional)")
                        } footer: {
                            Text(store.codeNote)
                        }
                        Section {
                            Button(store.isBusy ? "Sending…" : "Send confirmation code", role: .destructive) {
                                Task { await store.sendCode() }
                            }
                            .disabled(!store.canSendCode)
                        }
                    }
                case .confirm:
                    if let impact = store.impact {
                        Section {
                            NoticeCard(title: String(localized: "Code sent to \(store.sentTo)"),
                                       message: String(localized: "Type it below. It works for \(impact.codeExpiresInMinutes) minutes, and you get five tries."))
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        Section {
                            TextField("000000", text: $store.code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                            TextField(impact.confirmationPhrase, text: $store.phrase)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        } footer: {
                            Text("Type \(impact.confirmationPhrase) to confirm")
                        }
                        Section {
                            Button(store.isBusy ? "Deleting…" : "Delete my account permanently", role: .destructive) {
                                Task { await store.deleteAccount() }
                            }
                            .disabled(!store.canDelete)
                        }
                    }
                case .done:
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Color.maqrLive)
                            Text("Your account is deleted").font(.title3.weight(.bold))
                            Text("Everything you made has been removed and your codes no longer open anything. Thanks for trying maQR.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        Button("Done") {
                            dismiss()
                            store.finish()
                        }
                    }
                }
                if let failure = store.failure {
                    Section { NoticeCard(title: String(localized: "That didn’t work"), message: failure, kind: .alert) }
                }
            }
            .navigationTitle(store.stage == .done ? "" : String(localized: "Delete your account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.stage != .done {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.isBusy) }
                }
            }
        }
        .interactiveDismissDisabled(store.isBusy || store.stage == .done)
        .sensoryFeedback(.warning, trigger: store.stage)
        .task { await store.load() }
    }
}
