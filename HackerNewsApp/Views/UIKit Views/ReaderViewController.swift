import UIKit
import SafariServices

@MainActor
final class ReaderViewController: UIViewController, UITextViewDelegate {
    private let vm: ReaderViewModel
    private let globalSettings: GlobalSettingsViewModel
    private let proFeatureGate = ProFeatureGate.shared

    private let textView = UITextView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private var tocTargets: [(title: String, location: Int)] = []

    init(story: Story, globalSettings: GlobalSettingsViewModel) {
        self.vm = ReaderViewModel(story: story)
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    init(url: URL, title: String, globalSettings: GlobalSettingsViewModel) {
        self.vm = ReaderViewModel(url: url, title: title)
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reader"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureNavigation()
        configureViews()

        Task {
            await vm.load()
            render()
        }
    }

    private func configureNavigation() {
        updateNavigationItems()
    }

    private func updateNavigationItems() {
        var items: [UIBarButtonItem] = [
            UIBarButtonItem(image: UIImage(systemName: "textformat.size"), primaryAction: UIAction { [weak self] _ in self?.showTypographyMenu() }),
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.vm.reload()
                    self.render()
                }
            }),
            UIBarButtonItem(image: UIImage(systemName: "safari"), primaryAction: UIAction { [weak self] _ in self?.openInSafari() })
        ]

        if proFeatureGate.isPro, !vm.tableOfContents.isEmpty {
            items.insert(
                UIBarButtonItem(
                    image: UIImage(systemName: "list.bullet.indent"),
                    primaryAction: UIAction { [weak self] _ in self?.showTOC() }
                ),
                at: 0
            )
        }
        navigationItem.rightBarButtonItems = items
    }

    private func configureViews() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 22, right: 16)
        textView.delegate = self
        textView.adjustsFontForContentSizeCategory = true

        spinner.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.font = .preferredFont(forTextStyle: .body)

        view.addSubview(textView)
        view.addSubview(spinner)
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func render() {
        switch vm.loadState {
        case .idle, .loading:
            spinner.startAnimating()
            messageLabel.isHidden = true
            textView.isHidden = true
        case .empty:
            spinner.stopAnimating()
            textView.isHidden = true
            messageLabel.isHidden = false
            messageLabel.text = "Couldn't extract readable text."
        case .error(let message, _):
            spinner.stopAnimating()
            textView.isHidden = true
            messageLabel.isHidden = false
            messageLabel.text = message
        case .loaded:
            spinner.stopAnimating()
            messageLabel.isHidden = true
            textView.isHidden = false
            if proFeatureGate.isPro {
                navigationItem.prompt = "\(vm.estimatedReadTimeMinutes) min read"
            } else {
                navigationItem.prompt = nil
            }
            updateNavigationItems()
            Task { @MainActor in
                let (attributed, targets) = await makeAttributedContent()
                self.tocTargets = targets
                self.textView.attributedText = attributed
            }
        }
    }

    private func makeAttributedContent() async -> (NSAttributedString, [(title: String, location: Int)]) {
        guard let content = vm.content else { return (NSAttributedString(string: ""), []) }
        let isPro = proFeatureGate.isPro

        let basePointSize = UIFont.preferredFont(forTextStyle: .body).pointSize * globalSettings.settings.readerFontScale
        let bodyFont = UIFont.systemFont(ofSize: basePointSize)
        let headingFont = UIFont.boldSystemFont(ofSize: basePointSize * 1.28)
        let subheadingFont = UIFont.boldSystemFont(ofSize: basePointSize * 1.12)

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = globalSettings.settings.readerLineSpacing

        let result = NSMutableAttributedString()
        var targets: [(title: String, location: Int)] = []

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: basePointSize * 1.35),
            .foregroundColor: UIColor.label
        ]
        result.append(NSAttributedString(string: content.title + "\n\n", attributes: titleAttrs))

        for block in content.blocks {
            switch block {
            case .heading(let text, let level):
                let font = level <= 2 ? headingFont : subheadingFont
                targets.append((title: text, location: result.length))
                result.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: font,
                    .foregroundColor: UIColor.label
                ]))
            case .paragraph(let spans):
                let paragraphText = NSMutableAttributedString()
                for span in spans {
                    switch span {
                    case .text(let text):
                        paragraphText.append(NSAttributedString(string: text, attributes: [
                            .font: bodyFont,
                            .foregroundColor: UIColor.label,
                            .paragraphStyle: bodyParagraph
                        ]))
                    case .link(let text, let url):
                        paragraphText.append(NSAttributedString(string: text, attributes: [
                            .font: bodyFont,
                            .foregroundColor: UIColor.systemOrange,
                            .paragraphStyle: bodyParagraph,
                            .link: url
                        ]))
                    }
                }
                result.append(paragraphText)
                result.append(NSAttributedString(string: "\n\n"))
            case .quote(let text):
                result.append(NSAttributedString(string: "\u{201C}\(text)\u{201D}\n\n", attributes: [
                    .font: UIFont.italicSystemFont(ofSize: basePointSize),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: bodyParagraph
                ]))
            case .code(let text):
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = globalSettings.settings.readerLineSpacing
                paragraph.firstLineHeadIndent = isPro ? 10 : 0
                paragraph.headIndent = isPro ? 10 : 0
                paragraph.paragraphSpacingBefore = isPro ? 4 : 0
                paragraph.paragraphSpacing = isPro ? 6 : 0
                result.append(NSAttributedString(string: text + "\n\n", attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: max(basePointSize - 1, 12), weight: .regular),
                    .foregroundColor: UIColor.label,
                    .backgroundColor: isPro ? UIColor.systemGray6 : UIColor.clear,
                    .paragraphStyle: paragraph
                ]))
            case .image(let url, let alt):
                if isPro, let imageAttachment = await loadImageAttachment(from: url) {
                    let imageText = NSMutableAttributedString()
                    imageText.append(NSAttributedString(attachment: imageAttachment))
                    imageText.append(NSAttributedString(string: "\n"))
                    if let alt, !alt.isEmpty {
                        imageText.append(NSAttributedString(string: alt + "\n", attributes: [
                            .font: UIFont.preferredFont(forTextStyle: .caption1),
                            .foregroundColor: UIColor.secondaryLabel
                        ]))
                    }
                    imageText.append(NSAttributedString(string: "\n"))
                    result.append(imageText)
                } else {
                    let fallback = alt?.isEmpty == false ? alt! : url.absoluteString
                    result.append(NSAttributedString(string: fallback + "\n\n", attributes: [
                        .font: bodyFont,
                        .foregroundColor: UIColor.systemOrange,
                        .paragraphStyle: bodyParagraph,
                        .link: url
                    ]))
                }
            case .listItem(let text, let ordered):
                let prefix = ordered ? "1. " : "• "
                result.append(NSAttributedString(string: prefix + text + "\n", attributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: bodyParagraph
                ]))
            }
        }

        return (result, targets)
    }

    private func loadImageAttachment(from url: URL) async -> NSTextAttachment? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            let attachment = NSTextAttachment()
            attachment.image = image

            let availableWidth = max(textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right, 260)
            let ratio = image.size.height / max(image.size.width, 1)
            attachment.bounds = CGRect(x: 0, y: 0, width: availableWidth, height: availableWidth * ratio)
            return attachment
        } catch {
            return nil
        }
    }

    private func openInSafari() {
        guard let safeURL = vm.safeURL else { return }
        present(SFSafariViewController(url: safeURL), animated: true)
    }

    private func showTypographyMenu() {
        let menu = UIAlertController(title: "Typography", message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Reset to Default", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.readerFontScale = 1.0
            self.globalSettings.settings.readerLineSpacing = 2.0
            self.render()
        }))
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(menu, animated: true)
    }

    private func showTOC() {
        guard !tocTargets.isEmpty else { return }
        let menu = UIAlertController(title: "Table of Contents", message: nil, preferredStyle: .actionSheet)
        for target in tocTargets {
            menu.addAction(UIAlertAction(title: target.title, style: .default) { [weak self] _ in
                guard let self else { return }
                let range = NSRange(location: target.location, length: 0)
                self.textView.scrollRangeToVisible(range)
                self.textView.selectedRange = range
            })
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(menu, animated: true)
    }

    private func resolveReaderLink(_ url: URL) -> ReaderLinkResolution {
        ReaderLinkHandler.resolve(
            url: url,
            prefersReader: globalSettings.settings.openReaderLinksInReader,
            fallbackTitle: url.host ?? "Linked Article"
        )
    }

    private func openLinkInReader(url: URL, title: String) {
        navigationController?.pushViewController(
            ReaderViewController(url: url, title: title, globalSettings: globalSettings),
            animated: true
        )
    }

    private func presentLinkActionSheet(_ action: ReaderLinkActionData) {
        let menu = UIAlertController(title: "Open Link", message: action.url.absoluteString, preferredStyle: .actionSheet)
        if action.canOpenInReader {
            menu.addAction(UIAlertAction(title: "Open in Reader", style: .default) { [weak self] _ in
                guard let self else { return }
                self.openLinkInReader(url: action.url, title: action.url.host ?? "Linked Article")
            })
        }
        menu.addAction(UIAlertAction(title: "Open in Safari", style: .default) { [weak self] _ in
            self?.present(SFSafariViewController(url: action.url), animated: true)
        })
        menu.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            UIPasteboard.general.url = action.url
        })
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(menu, animated: true)
    }

    private func makeLinkMenu(for action: ReaderLinkActionData) -> UIMenu {
        var actions: [UIAction] = []
        if action.canOpenInReader {
            actions.append(
                UIAction(title: "Open in Reader", image: UIImage(systemName: "doc.text")) { [weak self] _ in
                    guard let self else { return }
                    self.openLinkInReader(url: action.url, title: action.url.host ?? "Linked Article")
                }
            )
        }
        actions.append(
            UIAction(title: "Open in Safari", image: UIImage(systemName: "safari")) { [weak self] _ in
                self?.present(SFSafariViewController(url: action.url), animated: true)
            }
        )
        actions.append(
            UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = action.url
            }
        )
        return UIMenu(children: actions)
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case let .link(url) = textItem.content else {
            return defaultAction
        }

        switch resolveReaderLink(url) {
        case .openInReader(let linkedURL, let title):
            return UIAction { [weak self] _ in
                self?.openLinkInReader(url: linkedURL, title: title)
            }
        case .showAction(let action):
            return UIAction { [weak self] _ in
                self?.presentLinkActionSheet(action)
            }
        }
    }

    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        guard case let .link(url) = textItem.content else {
            return nil
        }

        switch resolveReaderLink(url) {
        case .openInReader(let linkedURL, _):
            let action = ReaderLinkActionData(url: linkedURL, canOpenInReader: true)
            return UITextItem.MenuConfiguration(menu: makeLinkMenu(for: action))
        case .showAction(let action):
            return UITextItem.MenuConfiguration(menu: makeLinkMenu(for: action))
        }
    }
}
