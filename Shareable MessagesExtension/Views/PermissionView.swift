//
//  PermissionView.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI
import Contacts

struct PermissionView: View {
    let status: CNAuthorizationStatus
    let onOpenApp: () -> Void

    var body: some View {
        if status == .restricted {
            StatusMessageView(
                systemImage: "lock",
                title: "Contacts Restricted",
                message: "Access to contacts is limited by Screen Time or a device profile."
            )
        } else {
            StatusMessageView(
                systemImage: "person.crop.circle",
                title: "Shareable Needs Your Contacts",
                message: status == .denied
                    ? "Contacts access is turned off. Open Shareable to turn it back on."
                    : "Open Shareable to allow contacts access, then come back to this chat.",
                actionTitle: "Open Shareable",
                action: onOpenApp
            )
        }
    }
}
