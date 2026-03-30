import UIKit
import SwiftUI

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        // Attempt to get the source app's bundle ID from the extension context
        let sourceBundleID = extensionContext?
            .inputItems
            .compactMap { ($0 as? NSExtensionItem)?.userInfo?["NSExtensionItemSourceApplicationIdentifierKey"] as? String }
            .first

        let shareView = ShareView(
            extensionItems: items,
            sourceBundleID: sourceBundleID,
            onDismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }
}
