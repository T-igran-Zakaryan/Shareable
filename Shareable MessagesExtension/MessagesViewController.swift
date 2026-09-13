//
//  MessagesViewController.swift
//  Shareable MessagesExtension
//
//  Created by Тигран Закарян on 12.09.26.
//

import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    private let coordinator = ConversationCoordinator()
    private let contactManager = ContactManager()
    private var hostingController: UIHostingController<MessagesRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        coordinator.controller = self
        setupSwiftUIInterface()

        // Returning from the Shareable app or Settings may have changed contacts access.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hostWillEnterForeground),
            name: .NSExtensionHostWillEnterForeground,
            object: nil
        )
    }

    @objc private func hostWillEnterForeground() {
        contactManager.checkAuthorizationAndFetch()
    }

    // MARK: - SwiftUI Embedding

    private func setupSwiftUIInterface() {
        let rootView = MessagesRootView(
            contactManager: contactManager,
            coordinator: coordinator
        )

        let hostingVC = UIHostingController(rootView: rootView)
        self.hostingController = hostingVC

        addChild(hostingVC)
        view.addSubview(hostingVC.view)

        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingVC.didMove(toParent: self)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)

        coordinator.activeConversation = conversation
        coordinator.presentationStyle = presentationStyle
        contactManager.checkAuthorizationAndFetch()
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
    }

    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        super.didCancelSending(message, conversation: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        coordinator.willTransition(to: presentationStyle)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        coordinator.didTransition(to: presentationStyle)
    }
}
