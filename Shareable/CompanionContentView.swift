//
//  CompanionContentView.swift
//  Shareable
//
//  Created for Shareable.
//

import SwiftUI
import Contacts

struct CompanionContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    Text("Send contact cards without leaving the conversation.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    accessSection
                    stepsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Shareable")
            .safeAreaInset(edge: .bottom) {
                openMessagesButton
            }
        }
        .tint(.primary)
        // The Messages extension opens shareable:// when it has no contacts access.
        .onOpenURL { _ in
            if authorizationStatus == .notDetermined {
                requestAccess()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            }
        }
    }

    // MARK: - Access

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Contacts Access")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isAuthorized ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(isAuthorized ? .primary : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(accessTitle)
                        .font(.body.weight(.medium))

                    Text(accessDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            switch authorizationStatus {
            case .notDetermined:
                Button("Allow Access", action: requestAccess)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            case .denied, .limited:
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            default:
                EmptyView()
            }
        }
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    private var accessTitle: LocalizedStringKey {
        switch authorizationStatus {
        case .authorized: "Allowed"
        case .limited: "Allowed for some contacts"
        case .denied: "Turned off"
        case .restricted: "Restricted"
        default: "Not allowed yet"
        }
    }

    private var accessDetail: LocalizedStringKey {
        switch authorizationStatus {
        case .authorized: "Your contacts are ready to share in Messages."
        case .limited: "Only the contacts you picked appear in Messages."
        case .denied: "Turn on Contacts for Shareable in Settings."
        case .restricted: "Contacts access is limited on this device."
        default: "Shareable needs your contacts to show them in Messages. They never leave your device."
        }
    }

    private func requestAccess() {
        Task {
            _ = try? await CNContactStore().requestAccess(for: .contacts)
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("How to Use")

            stepRow(1, title: "Open a conversation", detail: "Any chat in Messages.")
            stepRow(2, title: "Tap +", detail: "Next to the message field.")
            stepRow(3, title: "Choose Shareable", detail: "Tap More if you don't see it.")
            stepRow(4, title: "Tap ↑ on a contact", detail: "Or tap the contact to pick which details to send.")
        }
    }

    private func stepRow(_ number: Int, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(number, format: .number)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Open Messages

    private var openMessagesButton: some View {
        Button {
            if let url = URL(string: "sms:") {
                openURL(url)
            }
        } label: {
            Text("Open Messages")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color(.label))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }
}
