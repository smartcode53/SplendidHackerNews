import SwiftUI

struct ReaderView: View {
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Environment(\.openURL) var openURL
    @StateObject private var vm: ReaderViewModel
    @State private var showTypography = false

    init(story: Story) {
        _vm = StateObject(wrappedValue: ReaderViewModel(story: story))
    }

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            content
        }
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

                Button {
                    Task { await vm.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)

                Button {
                    showTypography = true
                } label: {
                    Image(systemName: "textformat.size")
                }
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
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView("Loading article...")
                .foregroundColor(.secondary)
        case .failed(let message):
            fallbackView(message: message)
        case .success(let content):
            readerContentView(content: content)
        }
    }

    private var isLoading: Bool {
        if case .loading = vm.state {
            return true
        }
        return false
    }

    private func openInSafari() {
        guard let safeURL = vm.safeURL else { return }
        openURL(safeURL, prefersInApp: true)
    }

    private func readerContentView(content: ReaderContent) -> some View {
        let typography = ReaderTypography(fontScale: globalSettings.settings.readerFontScale,
                                          lineSpacing: globalSettings.settings.readerLineSpacing)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)

                    if let domain = content.domain {
                        Text("\(domain) • \(content.urlString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(content.urlString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if content.isTruncated {
                    Text("Content truncated for performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(content.blocks.enumerated()), id: \.offset) { _, block in
                    ReaderBlockView(
                        block: block,
                        typography: typography
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private func fallbackView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Couldn't extract this article.")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Open in Safari") {
                    openInSafari()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.safeURL == nil)

                Button("Try again") {
                    Task { await vm.reload() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }
}

private struct ReaderTypography {
    let fontScale: Double
    let lineSpacing: Double

    var bodyFont: Font {
        .system(size: 17 * fontScale)
    }

    var codeFont: Font {
        .system(size: 15 * fontScale, design: .monospaced)
    }

    func headingFont(level: Int) -> Font {
        .system(size: headingSize(for: level) * fontScale, weight: .semibold)
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1:
            return 26
        case 2:
            return 22
        case 3:
            return 20
        case 4:
            return 18
        default:
            return 17
        }
    }
}

private struct ReaderBlockView: View {
    let block: ReaderBlock
    let typography: ReaderTypography

    var body: some View {
        switch block {
        case .heading(let text, let level):
            Text(text)
                .font(typography.headingFont(level: level))
                .foregroundColor(.primary)
                .lineSpacing(typography.lineSpacing)
                .padding(.top, level <= 2 ? 6 : 0)
        case .paragraph(let text):
            Text(text)
                .font(typography.bodyFont)
                .foregroundColor(.primary)
                .lineSpacing(typography.lineSpacing)
        case .code(let text):
            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(typography.codeFont)
                    .foregroundColor(.primary)
                    .lineSpacing(typography.lineSpacing)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color("CardColor").opacity(0.7))
                    )
            }
        case .quote(let text):
            Text(text)
                .font(typography.bodyFont)
                .foregroundColor(.secondary)
                .lineSpacing(typography.lineSpacing)
                .padding(.leading, 12)
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3),
                    alignment: .leading
                )
        }
    }
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
                    Text("Scale: \(fontScale, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }

                Section("Line Spacing") {
                    Slider(value: $lineSpacing, in: 1...10, step: 1)
                    Text("Spacing: \(lineSpacing, specifier: "%.0f")")
                        .foregroundColor(.secondary)
                }

                Section("Current Typography") {
                    Text("Scale \(fontScale, specifier: "%.2f"), spacing \(lineSpacing, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Reset to Default") {
                        fontScale = 1.0
                        lineSpacing = 4.0
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

#if DEBUG
struct ReaderPreviewView: View {
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel

    private let blocks: [ReaderBlock] = [
        .heading("Reader Typography Preview", level: 1),
        .paragraph("This paragraph previews body text. Adjust font size and line spacing in Settings > Reader or the typography sheet to see it update here."),
        .heading("Subheading Level 2", level: 2),
        .paragraph("Line spacing should affect each paragraph block independently. This is a second paragraph to make spacing changes more obvious."),
        .quote("Quoted text should remain legible and respect line spacing while staying visually distinct."),
        .code("let greeting = \"Hello, Hacker News\"\nprint(greeting)\n// Monospaced text should remain readable and scroll horizontally if needed.")
    ]

    var body: some View {
        let typography = ReaderTypography(fontScale: globalSettings.settings.readerFontScale,
                                          lineSpacing: globalSettings.settings.readerLineSpacing)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reader Preview")
                        .font(.title2.weight(.semibold))
                    Text(String(format: "Scale %.2f, spacing %.0f",
                                globalSettings.settings.readerFontScale,
                                globalSettings.settings.readerLineSpacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    ReaderBlockView(block: block, typography: typography)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Reader Preview")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("BackgroundColor"))
    }
}
#endif
