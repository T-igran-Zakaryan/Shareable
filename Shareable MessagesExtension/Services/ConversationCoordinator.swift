//
//  ConversationCoordinator.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import Foundation
import Messages
import SwiftUI
import Observation

/// Coordinates between SwiftUI views and the underlying MSMessagesAppViewController & MSConversation.
@Observable
@MainActor
public final class ConversationCoordinator {

    // MARK: - State

    public var presentationStyle: MSMessagesAppPresentationStyle = .compact
    public var isSharing = false
    /// Drives the expanded list's search field, so the compact search pill can open straight into typing.
    public var isSearchActive = false
    /// The contact most recently attached to the composer, used for a brief inline confirmation on its row.
    public var lastSharedContactID: ShareableContact.ID?
    public var shareError: String?
    public var isShowingShareError = false

    // MARK: - Weak Controller Reference

    public weak var controller: MSMessagesAppViewController?
    public var activeConversation: MSConversation?

    private var searchActivationPending = false
    private var sharedConfirmationTask: Task<Void, Never>?

    /// Custom scheme registered by the Shareable app, used to send the user there to grant contacts access.
    private static let containingAppURL = URL(string: "shareable://contacts-access")!

    public init() {}

    // MARK: - Presentation Style Management

    public func requestPresentationStyle(_ style: MSMessagesAppPresentationStyle) {
        controller?.requestPresentationStyle(style)
    }

    /// Closes the iMessage app entirely, back to the conversation transcript.
    /// Used where collapsing isn't possible, such as landscape on iPhone.
    public func dismissExtension() {
        controller?.dismiss()
    }

    /// The keyboard is unavailable in compact mode, so expand first and activate search once the transition lands.
    public func expandForSearch() {
        if presentationStyle == .expanded {
            isSearchActive = true
        } else {
            searchActivationPending = true
            requestPresentationStyle(.expanded)
        }
    }

    public func willTransition(to style: MSMessagesAppPresentationStyle) {
        presentationStyle = style
        if style == .compact {
            isSearchActive = false
            searchActivationPending = false
        }
    }

    public func didTransition(to style: MSMessagesAppPresentationStyle) {
        presentationStyle = style
        if style == .expanded && searchActivationPending {
            isSearchActive = true
        }
        searchActivationPending = false
    }

    // MARK: - Containing App

    public func openContainingApp() {
        controller?.extensionContext?.open(Self.containingAppURL, completionHandler: nil)
    }

    // MARK: - Sharing Actions

    /// Generates full vCard file and inserts it directly into the active iMessage composition bar.
    public func shareFullContact(_ contact: ShareableContact) {
        share(contact) {
            try VCardService.createVCardFile(for: contact)
        }
    }

    /// Generates selective vCard file containing only the user-approved fields and inserts into iMessage.
    public func shareSelectiveContact(
        _ contact: ShareableContact,
        selectedPhoneIDs: Set<String>,
        selectedEmailIDs: Set<String>,
        selectedAddressIDs: Set<String>,
        includePhoto: Bool
    ) {
        share(contact) {
            try VCardService.createFilteredVCardFile(
                for: contact,
                selectedPhoneIDs: selectedPhoneIDs,
                selectedEmailIDs: selectedEmailIDs,
                selectedAddressIDs: selectedAddressIDs,
                includePhoto: includePhoto
            )
        }
    }

    private func share(_ contact: ShareableContact, makeFile: () throws -> (url: URL, filename: String)) {
        guard let conversation = activeConversation ?? controller?.activeConversation else {
            showShareError("No active conversation found in Messages.")
            return
        }

        let file: (url: URL, filename: String)
        do {
            file = try makeFile()
        } catch {
            showShareError(error.localizedDescription)
            return
        }

        isSharing = true

        Task {
            defer { isSharing = false }

            do {
                try await conversation.insertAttachment(file.url, withAlternateFilename: file.filename)
                confirmShared(contact.id)

                // Collapse back to compact drawer so user can immediately see the composer and send
                if presentationStyle == .expanded {
                    requestPresentationStyle(.compact)
                }
            } catch {
                showShareError(error.localizedDescription)
            }
        }
    }

    private func confirmShared(_ id: ShareableContact.ID) {
        lastSharedContactID = id
        sharedConfirmationTask?.cancel()
        sharedConfirmationTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            lastSharedContactID = nil
        }
    }

    private func showShareError(_ message: String) {
        shareError = message
        isShowingShareError = true
    }
}
