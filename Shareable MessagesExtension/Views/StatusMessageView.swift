//
//  StatusMessageView.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI

/// A small centered message with an optional action, sized to fit the compact Messages drawer.
struct StatusMessageView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .vertical) {
            content

            ScrollView {
                content
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(.label))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 420)
    }
}
