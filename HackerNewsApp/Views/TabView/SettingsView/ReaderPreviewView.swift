import SwiftUI
import UIKit

#if DEBUG
struct ReaderPreviewView: View {
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Environment(\.openURL) var openURL
    @State private var linkAction: ReaderLinkActionData?
    @State private var linkDestination: ReaderPreviewDestination?
    @State private var showLinkHitboxes = false

    private let title: String

    init(title: String = "Reader Preview") {
        self.title = title
    }

    private var blocks: [ReaderBlock] {
        [
            .heading("Reader Typography Preview", level: 1),
            .heading("Subheading Level 2", level: 2),
            .paragraph([
                .text("This paragraph includes "),
                .link(text: "OpenAI", url: URL(string: "https://openai.com")!),
                .text(" and "),
                .link(text: "Hacker News", url: URL(string: "https://news.ycombinator.com")!),
                .text(" links to validate tap handling.")
            ]),
            .quote("Quoted text should remain legible and respect line spacing while staying visually distinct."),
            .code("let greeting = \"Hello, Hacker News\"\nprint(greeting)\n// Long line for horizontal scrolling: let preview = \"0123456789\" + String(repeating: \"X\", count: 80)")
        ]
    }

    var body: some View {
        let typography = ReaderTypography(
            fontScale: globalSettings.settings.readerFontScale,
            lineSpacing: globalSettings.settings.readerLineSpacing
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(String(format: "Scale %.2f, spacing %.0f",
                                globalSettings.settings.readerFontScale,
                                globalSettings.settings.readerLineSpacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Toggle("Show link hitboxes", isOn: $showLinkHitboxes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    ReaderBlockView(
                        block: block,
                        typography: typography,
                        showLinkHitboxes: showLinkHitboxes,
                        onLinkTap: handleLinkTap
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("BackgroundColor"))
        .background(linkNavigation)
        .confirmationDialog("Open Link", isPresented: isLinkActionPresented, presenting: linkAction) { action in
            if action.canOpenInReader {
                Button("Open in Reader") {
                    openLinkInReader(action.url)
                }
            }
            Button("Open in Safari") {
                openURL(action.url, prefersInApp: true)
            }
            Button("Copy Link") {
                UIPasteboard.general.url = action.url
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.url.absoluteString)
        }
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

    private var linkNavigation: some View {
        NavigationLink(
            destination: Group {
                if let destination = linkDestination {
                    ReaderPreviewView(title: destination.title)
                }
            },
            isActive: Binding(
                get: { linkDestination != nil },
                set: { isActive in
                    if !isActive {
                        linkDestination = nil
                    }
                }
            ),
            label: { EmptyView() }
        )
        .hidden()
    }

    private func handleLinkTap(_ url: URL) {
        switch ReaderLinkHandler.resolve(
            url: url,
            prefersReader: globalSettings.settings.openReaderLinksInReader,
            fallbackTitle: title
        ) {
        case .openInReader(let url, let title):
            linkDestination = ReaderPreviewDestination(url: url, title: title)
        case .showAction(let action):
            linkAction = action
        }
    }

    private func openLinkInReader(_ url: URL) {
        guard ReaderLinkPolicy.canOpenInReader(url) else {
            openURL(url, prefersInApp: true)
            return
        }
        let title = url.host ?? "Reader Preview"
        linkDestination = ReaderPreviewDestination(url: url, title: title)
    }
}

private struct ReaderPreviewDestination {
    let url: URL
    let title: String
}
#endif
