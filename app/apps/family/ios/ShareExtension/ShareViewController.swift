import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

/// A link shared from another app. It is written into the group the app
/// shares with this extension, and the app is opened to deal with it: the
/// page itself is fetched by the phone, never by a server.
class ShareViewController: UIViewController {
    private let appGroup = "group.io.github.johancarlstedt.family"
    private let scheme = "familyplanner"

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let providers = item.attachments
        else {
            return finish()
        }
        let url = UTType.url.identifier
        let text = UTType.plainText.identifier

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(url) {
                provider.loadItem(forTypeIdentifier: url, options: nil) { value, _ in
                    self.hand(over: (value as? URL)?.absoluteString)
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(text) {
                provider.loadItem(forTypeIdentifier: text, options: nil) { value, _ in
                    self.hand(over: value as? String)
                }
                return
            }
        }
        finish()
    }

    private func hand(over shared: String?) {
        if let shared, !shared.isEmpty {
            UserDefaults(suiteName: appGroup)?.set(shared, forKey: "shared.link")
        }
        DispatchQueue.main.async {
            self.open(URL(string: "\(self.scheme)://share"))
            self.finish()
        }
    }

    /// Extensions may not open a URL directly; the responder chain may.
    private func open(_ url: URL?) {
        guard let url else { return }
        var responder: UIResponder? = self
        while let next = responder {
            if let application = next as? UIApplication {
                application.open(url)
                return
            }
            responder = next.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
