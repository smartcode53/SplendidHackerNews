import SwiftUI
import UIKit

struct ReaderBlockView: View {
    let block: ReaderBlock
    let typography: ReaderTypography
    let showLinkHitboxes: Bool
    let onLinkTap: (URL) -> Void

    init(
        block: ReaderBlock,
        typography: ReaderTypography,
        showLinkHitboxes: Bool = false,
        onLinkTap: @escaping (URL) -> Void
    ) {
        self.block = block
        self.typography = typography
        self.showLinkHitboxes = showLinkHitboxes
        self.onLinkTap = onLinkTap
    }

    var body: some View {
        switch block {
        case .heading(let text, let level):
            Text(text)
                .font(typography.headingFont(level: level))
                .foregroundColor(.primary)
                .lineSpacing(typography.lineSpacing)
                .padding(.top, level <= 2 ? 6 : 0)
        case .paragraph(let spans):
            ReaderParagraphView(
                spans: spans,
                typography: typography,
                showLinkHitboxes: showLinkHitboxes,
                onLinkTap: onLinkTap
            )
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
                .font(typography.quoteFont)
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

private struct ReaderParagraphView: View {
    let spans: [ReaderSpan]
    let typography: ReaderTypography
    let showLinkHitboxes: Bool
    let onLinkTap: (URL) -> Void

    var body: some View {
        LinkTextView(
            attributedText: attributedText,
            onLinkTap: onLinkTap,
            linkColor: UIColor(Color.accentColor)
        )
    }

    private var attributedText: NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.lineSpacing

        for span in spans {
            switch span {
            case .text(let value):
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: typography.bodyUIFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: value, attributes: attributes))
            case .link(let value, let url):
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: typography.bodyUIFont,
                    .foregroundColor: UIColor(Color.accentColor),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: url,
                    .paragraphStyle: paragraphStyle
                ]
                if showLinkHitboxes {
                    attributes[.backgroundColor] = UIColor.systemYellow.withAlphaComponent(0.2)
                }
                result.append(NSAttributedString(string: value, attributes: attributes))
            }
        }
        return result
    }
}
