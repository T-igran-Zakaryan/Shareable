//
//  ContactRowView.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI

struct ContactRowView: View {
    let contact: ShareableContact
    /// True briefly after this contact was attached, so the row itself confirms the share.
    let isShared: Bool
    let onQuickShare: () -> Void
    let onCustomizeShare: () -> Void

    @ScaledMetric private var avatarSize = 40.0
    @ScaledMetric private var shareButtonSize = 32.0

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCustomizeShare) {
                HStack(spacing: 12) {
                    ContactAvatarView(contact: contact)
                        .frame(width: avatarSize, height: avatarSize)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(contact.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if let subtitle = contact.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose which details to share")

            Button {
                // Ignore repeat taps while the confirmation shows, without dimming it like `.disabled` would.
                if !isShared {
                    onQuickShare()
                }
            } label: {
                Label(
                    isShared ? "Added \(contact.displayName)" : "Share \(contact.displayName)",
                    systemImage: isShared ? "checkmark" : "arrow.up"
                )
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isShared ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.primary))
                .frame(width: shareButtonSize, height: shareButtonSize)
                .background(isShared ? AnyShapeStyle(.primary) : AnyShapeStyle(.fill.tertiary), in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .animation(.snappy, value: isShared)
        }
    }
}
