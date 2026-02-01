import SwiftUI
import UIKit

#if DEBUG

struct HNDiagnosticsView: View {
    @EnvironmentObject var account: HNAccount
    @StateObject private var vm: HNDiagnosticsViewModel

    init(account: HNAccount) {
        _vm = StateObject(wrappedValue: HNDiagnosticsViewModel(account: account))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusSection
                configSection
                actionSection
                reportSection
                dryRunSection
            }
            .padding()
        }
        .navigationTitle("HN Diagnostics")
        .onAppear {
            vm.persistKnownIds()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Status")
                .font(.headline)
            HStack {
                Text("Logged In")
                Spacer()
                Text(account.isLoggedIn ? "Yes" : "No")
                    .foregroundColor(account.isLoggedIn ? .green : .secondary)
            }
            HStack {
                Text("Username")
                Spacer()
                Text(account.username ?? "-")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Last Verify")
                Spacer()
                Text(account.lastVerifyStatus ?? "-")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(12)
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configurable IDs")
                .font(.headline)
            TextField("Known Story ID", text: $vm.knownStoryIdText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: vm.knownStoryIdText) { _ in
                    vm.persistKnownIds()
                }
            TextField("Known Comment ID (optional)", text: $vm.knownCommentIdText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: vm.knownCommentIdText) { _ in
                    vm.persistKnownIds()
                }
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(12)
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selector Self-Test")
                .font(.headline)
            Button(vm.isRunning ? "Running..." : "Run Selector Self-Test") {
                vm.runSelfTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isRunning)

            Button("Copy Diagnostics") {
                if let report = vm.report {
                    UIPasteboard.general.string = report.formatted()
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.report == nil)
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(12)
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Report")
                .font(.headline)
            if let report = vm.report {
                ForEach(report.checks) { check in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(check.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(check.passed ? "PASS" : "FAIL")
                                .foregroundColor(check.passed ? .green : .red)
                        }
                        if !check.passed {
                            Text("Error: \(check.errorCode?.rawValue ?? "Unknown")")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("URL: \(check.url)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            if let status = check.statusCode {
                                Text("Status: \(status)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            if !check.selectors.isEmpty {
                                Text("Selectors: \(check.selectors.joined(separator: ", "))")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            if let message = check.message {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            if let excerpt = check.excerpt {
                                Text(excerpt)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(8)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color("BackgroundColor"))
                    .cornerRadius(10)
                }
            } else {
                Text("No report yet.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(12)
    }

    private var dryRunSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dry Run: Fetch Tokens")
                .font(.headline)
            Button(vm.isRunning ? "Running..." : "Dry Run: Fetch Vote/Reply Tokens") {
                vm.runDryRunTokens()
            }
            .buttonStyle(.bordered)
            .disabled(vm.isRunning)

            if let result = vm.dryRunResult {
                Text(result)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(12)
    }
}

#endif
