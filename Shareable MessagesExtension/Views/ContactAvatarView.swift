//
//  ContactAvatarView.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI

/// The contact's photo, or their initials on a neutral fill.
struct ContactAvatarView: View {
    let contact: ShareableContact
    var initialsFont: Font = .subheadline

    var body: some View {
        Circle()
            .fill(.fill.tertiary)
            .overlay {
                if let data = contact.thumbnailImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(contact.initials)
                        .font(initialsFont.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(.circle)
            .accessibilityHidden(true)
    }
}
