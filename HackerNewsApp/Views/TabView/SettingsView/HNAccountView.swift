import SwiftUI

struct HNAccountView: View {
    @EnvironmentObject var account: HNAccount
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @State private var showLogin = false
    @State private var isVerifying = false

    var body: some View {
        List {
            Section("Write Actions") {
                Toggle("Enable HN Write Actions (Debug)", isOn: Binding(
                    get: { globalSettings.settings.enableHNWriteActionsDebug },
                    set: { globalSettings.settings.enableHNWriteActionsDebug = $0 }
                ))
                .toggleStyle(.switch)
            }

            Section("Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(account.isLoggedIn ? "Logged In" : "Logged Out")
                        .foregroundColor(account.isLoggedIn ? .green : .secondary)
                }

                HStack {
                    Text("Username")
                    Spacer()
                    Text(account.username ?? "-")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Last Verified")
                    Spacer()
                    Text(account.lastVerifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Verify Result")
                    Spacer()
                    Text(account.lastVerifyStatus ?? "-")
                        .foregroundColor(.secondary)
                }

                if let error = account.lastError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Sign In") {
                    showLogin = true
                }
                .disabled(!globalSettings.settings.enableHNWriteActionsDebug)

                Button("Verify Session") {
                    isVerifying = true
                    Task {
                        _ = await account.verifySession()
                        isVerifying = false
                    }
                }
                .disabled(!account.isLoggedIn || isVerifying)

                Button("Sign Out", role: .destructive) {
                    account.signOut()
                }
                .disabled(!account.isLoggedIn)
            }
        }
        .navigationTitle("HN Account")
        .sheet(isPresented: $showLogin) {
            NavigationStack {
                HNLoginWebView { cookies in
                    account.handleLoginCookies(cookies)
                }
                .navigationTitle("HN Login")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showLogin = false
                        }
                    }
                }
            }
        }
    }
}
