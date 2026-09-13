//
//  ContactDetailSheet.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI

struct ContactDetailSheet: View {
    let contact: ShareableContact
    let onShareSelective: (_ selectedPhones: Set<String>, _ selectedEmails: Set<String>, _ selectedAddresses: Set<String>, _ includePhoto: Bool) -> Void
    let onShareFull: () -> Void
    let onDismiss: () -> Void

    @State private var selectedPhones: Set<String>
    @State private var selectedEmails: Set<String>
    @State private var selectedAddresses: Set<String>
    @State private var includePhoto: Bool

    @ScaledMetric private var avatarSize = 56.0

    init(
        contact: ShareableContact,
        onShareSelective: @escaping (_ selectedPhones: Set<String>, _ selectedEmails: Set<String>, _ selectedAddresses: Set<String>, _ includePhoto: Bool) -> Void,
        onShareFull: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.contact = contact
        self.onShareSelective = onShareSelective
        self.onShareFull = onShareFull
        self.onDismiss = onDismiss

        _selectedPhones = State(initialValue: Set(contact.phoneNumbers.map(\.id)))
        _selectedEmails = State(initialValue: Set(contact.emailAddresses.map(\.id)))
        _selectedAddresses = State(initialValue: Set(contact.postalAddresses.map(\.id)))
        _includePhoto = State(initialValue: contact.hasImageData)
    }

    private var totalSelectedCount: Int {
        selectedPhones.count + selectedEmails.count + selectedAddresses.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ContactAvatarView(contact: contact, initialsFont: .title3)
                            .frame(width: avatarSize, height: avatarSize)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName)
                                .font(.title3.weight(.semibold))

                            if let subtitle = contact.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)

                    if contact.hasImageData {
                        selectionRow(label: "Photo", value: "Include contact photo", isSelected: includePhoto) {
                            includePhoto.toggle()
                        }
                    }
                }

                if !contact.phoneNumbers.isEmpty {
                    Section("Phone") {
                        ForEach(contact.phoneNumbers) { phone in
                            selectionRow(label: phone.label, value: phone.value, isSelected: selectedPhones.contains(phone.id)) {
                                selectedPhones.formSymmetricDifference([phone.id])
                            }
                        }
                    }
                }

                if !contact.emailAddresses.isEmpty {
                    Section("Email") {
                        ForEach(contact.emailAddresses) { email in
                            selectionRow(label: email.label, value: email.value, isSelected: selectedEmails.contains(email.id)) {
                                selectedEmails.formSymmetricDifference([email.id])
                            }
                        }
                    }
                }

                if !contact.postalAddresses.isEmpty {
                    Section("Address") {
                        ForEach(contact.postalAddresses) { address in
                            selectionRow(label: address.label, value: address.formattedAddress, isSelected: selectedAddresses.contains(address.id)) {
                                selectedAddresses.formSymmetricDifference([address.id])
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                shareButtons
            }
            .navigationTitle("Share Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel, action: onDismiss)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(totalSelectedCount == 0 ? "Select All" : "Deselect All", action: toggleSelectAll)
                }
            }
        }
        .tint(.primary)
    }

    // MARK: - Pieces

    private var shareButtons: some View {
        VStack(spacing: 4) {
            Button {
                onShareSelective(selectedPhones, selectedEmails, selectedAddresses, includePhoto)
            } label: {
                Text("Share Selected (\(totalSelectedCount))")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Color(.label))
            .disabled(totalSelectedCount == 0 && contact.displayName.isEmpty)

            Button("Share Everything", action: onShareFull)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Color(.systemBackground))
    }

    private func selectionRow(label: String, value: String, isSelected: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleSelectAll() {
        if totalSelectedCount == 0 {
            selectedPhones = Set(contact.phoneNumbers.map(\.id))
            selectedEmails = Set(contact.emailAddresses.map(\.id))
            selectedAddresses = Set(contact.postalAddresses.map(\.id))
        } else {
            selectedPhones.removeAll()
            selectedEmails.removeAll()
            selectedAddresses.removeAll()
        }
    }
}
