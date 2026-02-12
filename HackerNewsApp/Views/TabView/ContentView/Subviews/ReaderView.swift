import SwiftUI
import UIKit

struct ReaderView: View {
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Environment(\.openURL) var openURL
    @StateObject private var vm: ReaderViewModel
    @State private var showTypography = false
    @State private var linkAction: ReaderLinkActionData?
    @State private var linkDestination: ReaderLinkDestination?

    init(story: Story) {
        _vm = StateObject(wrappedValue: ReaderViewModel(story: story))
    }

    init(url: URL, title: String) {
        _vm = StateObject(wrappedValue: ReaderViewModel(url: url, title: title))
    }

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reader View")
        .accessibilityIdentifier("reader.view")
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    openInSafari()
                } label: {
                    Image(systemName: "safari")
                }
                .disabled(vm.safeURL == nil)
                .accessibilityIdentifier("reader.openSafari")

                Button {
                    Task { await vm.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityIdentifier("reader.reload")

                Button {
                    showTypography = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityIdentifier("reader.typography")
            }
        }
        .sheet(isPresented: $showTypography) {
            ReaderTypographySheet(
                fontScale: $globalSettings.settings.readerFontScale,
                lineSpacing: $globalSettings.settings.readerLineSpacing
            )
        }
        .task {
            await vm.load()
        }
        .navigationDestination(item: $linkDestination) { destination in
            ReaderView(url: destination.url, title: destination.title)
        }
        .confirmationDialog("Open Link", isPresented: isLinkActionPresented, presenting: linkAction) { action in
            if action.canOpenInReader {
                Button("Open in Reader") {
                    openLinkInReader(action.url)
                }
                .accessibilityIdentifier("reader.link.openReader")
            }
            Button("Open in Safari") {
                openURL(action.url, prefersInApp: true)
            }
            .accessibilityIdentifier("reader.link.openSafari")
            Button("Copy Link") {
                UIPasteboard.general.url = action.url
            }
            .accessibilityIdentifier("reader.link.copy")
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.url.absoluteString)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.loadState {
        case .idle, .loading:
            ProgressView("Loading article...")
                .foregroundColor(.secondary)
        case .error(let message, _):
            fallbackView(title: "Couldn't load article.", message: message)
        case .empty:
            fallbackView(title: "Couldn't extract this article.", message: "We couldn't find readable text.")
        case .loaded:
            if let content = vm.content {
                readerContentView(content: content)
            } else {
                fallbackView(title: "Couldn't load article.", message: "Please try again.")
            }
        }
    }

    private var isLoading: Bool {
        vm.loadState.isLoading
    }

    private func openInSafari() {
        guard let safeURL = vm.safeURL else { return }
        openURL(safeURL, prefersInApp: true)
    }

    private func readerContentView(content: ReaderContent) -> some View {
        let typography = ReaderTypography(fontScale: globalSettings.settings.readerFontScale,
                                          lineSpacing: globalSettings.settings.readerLineSpacing)
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let domain = content.domain {
                        Text(domain)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }

                    Button {
                        openInSafari()
                    } label: {
                        Label("Open Source", systemImage: "safari")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)

#if DEBUG
                    if let lastUpdated = vm.lastUpdated {
                        Text("Last updated \(lastUpdatedLabel(for: lastUpdated))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
#endif
                }

                if content.isTruncated {
                    Text("Content truncated for performance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(content.blocks.enumerated()), id: \.offset) { index, block in
                    ReaderBlockView(
                        block: block,
                        typography: typography,
                        onLinkTap: handleLinkTap
                    )
                    .padding(.bottom, blockBottomSpacing(for: block, at: index, in: content.blocks))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func blockBottomSpacing(for block: ReaderBlock, at index: Int, in blocks: [ReaderBlock]) -> CGFloat {
        guard index < blocks.count - 1 else { return 0 }
        switch block {
        case .heading(_, let level):
            return level <= 2 ? 6 : 4
        case .paragraph:
            return 8
        case .quote:
            return 10
        case .code:
            return 10
        }
    }

    private func fallbackView(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

#if DEBUG
            if let lastUpdated = vm.lastUpdated {
                Text("Last updated \(lastUpdatedLabel(for: lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
#endif

            HStack(spacing: 12) {
                Button("Open in Safari") {
                    openInSafari()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.safeURL == nil)
                .accessibilityIdentifier("reader.openSafari")

                Button("Try again") {
                    Task { await vm.reload() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }

    private var isLinkActionPresented: Binding<Bool> {
        Binding(
            get: { linkAction != nil },
            set: { isPresented in
                if !isPresented {
                    linkAction = nil
                }
            }
        )
    }

    private func handleLinkTap(_ url: URL) {
        switch ReaderLinkHandler.resolve(
            url: url,
            prefersReader: globalSettings.settings.openReaderLinksInReader,
            fallbackTitle: "Linked Article"
        ) {
        case .openInReader(let url, let title):
            linkDestination = ReaderLinkDestination(url: url, title: title)
        case .showAction(let action):
            linkAction = action
        }
    }

    private func openLinkInReader(_ url: URL) {
        guard ReaderLinkPolicy.canOpenInReader(url) else {
            openURL(url, prefersInApp: true)
            return
        }
        let title = url.host ?? "Linked Article"
        linkDestination = ReaderLinkDestination(url: url, title: title)
    }

#if DEBUG
    private func lastUpdatedLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
#endif
}

private struct ReaderTypographySheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var fontScale: Double
    @Binding var lineSpacing: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Size") {
                    Slider(value: $fontScale, in: 0.9...1.4, step: 0.05)
                        .accessibilityIdentifier("reader.typography.fontScale")
                    Text("Scale: \(fontScale, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }

                Section("Line Spacing") {
                    Slider(value: $lineSpacing, in: 0...6, step: 0.5)
                        .accessibilityIdentifier("reader.typography.lineSpacing")
                    Text("Spacing: \(lineSpacing, specifier: "%.1f")")
                        .foregroundStyle(.secondary)
                }

                Section("Current Typography") {
                    Text("Scale \(fontScale, specifier: "%.2f"), spacing \(lineSpacing, specifier: "%.1f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset to Default") {
                        fontScale = 1.0
                        lineSpacing = 2.0
                    }
                }
            }
            .navigationTitle("Typography")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReaderView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderView(story: Story(by: "demo", descendants: nil, id: 1, score: 1, time: 0, title: "Preview", type: "story", url: "https://example.com"))
            .environmentObject(GlobalSettingsViewModel())
    }
}

private struct ReaderLinkDestination: Identifiable, Hashable {
    var id: String { url.absoluteString + title }
    let url: URL
    let title: String
}
