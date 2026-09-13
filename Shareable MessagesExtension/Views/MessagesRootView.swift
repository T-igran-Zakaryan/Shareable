//
//  MessagesRootView.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import SwiftUI
import Contacts
import Messages

struct MessagesRootView: View {
    @Bindable var contactManager: ContactManager
    @Bindable var coordinator: ConversationCoordinator

    @State private var sheetContact: ShareableContact?

    var body: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .tint(.primary)
            .sensoryFeedback(.success, trigger: coordinator.lastSharedContactID) { _, newValue in
                newValue != nil
            }
            .alert("Couldn't Share Contact", isPresented: $coordinator.isShowingShareError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(coordinator.shareError ?? "")
            }
            .onChange(of: coordinator.presentationStyle) { _, style in
                if style == .compact {
                    contactManager.searchQuery = ""
                }
            }
            .sheet(item: $sheetContact) { contact in
                ContactDetailSheet(
                    contact: contact,
                    onShareSelective: { phones, emails, addresses, includePhoto in
                        coordinator.shareSelectiveContact(
                            contact,
                            selectedPhoneIDs: phones,
                            selectedEmailIDs: emails,
                            selectedAddressIDs: addresses,
                            includePhoto: includePhoto
                        )
                        sheetContact = nil
                    },
                    onShareFull: {
                        coordinator.shareFullContact(contact)
                        sheetContact = nil
                    },
                    onDismiss: {
                        sheetContact = nil
                    }
                )
            }
    }

    // MARK: - Main Content Switcher

    @ViewBuilder
    private var contentView: some View {
        switch contactManager.authorizationStatus {
        case .authorized, .limited:
            if coordinator.presentationStyle == .compact {
                compactView
            } else {
                expandedView
            }
        default:
            PermissionView(status: contactManager.authorizationStatus, onOpenApp: coordinator.openContainingApp)
        }
    }

    // MARK: - Compact View (Keyboard Drawer Mode)

    private var compactView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // The keyboard can't appear in compact mode, so this opens full screen with search already active.
                Button(action: coordinator.expandForSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.fill.tertiary, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search Contacts")

                Button {
                    coordinator.requestPresentationStyle(.expanded)
                } label: {
                    Label("Show All Contacts", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.fill.tertiary, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if contactManager.isLoading && contactManager.contacts.isEmpty {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if contactManager.contacts.isEmpty {
                emptyState
            } else {
                List(contactManager.contacts) { contact in
                    row(for: contact)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Expanded View (Full Screen Mode)

    private var expandedView: some View {
        NavigationStack {
            Group {
                if contactManager.isLoading && contactManager.contacts.isEmpty {
                    ProgressView()
                } else if contactManager.contacts.isEmpty {
                    emptyState
                } else if contactManager.filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: contactManager.searchQuery)
                } else {
                    List {
                        ForEach(contactManager.sectionedContacts) { section in
                            Section(section.title) {
                                ForEach(section.contacts) { contact in
                                    // Extra trailing room keeps share buttons clear of the A–Z index.
                                    row(for: contact, trailingInset: 28)
                                }
                            }
                            .sectionIndexLabel(section.title)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .listSectionIndexVisibility(.visible)
                    .refreshable {
                        contactManager.fetchContacts()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .searchable(
                text: $contactManager.searchQuery,
                isPresented: $coordinator.isSearchActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Name, phone or email"
            )
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Collapse", systemImage: "chevron.down") {
                        coordinator.requestPresentationStyle(.compact)
                    }
                }
            }
        }
    }

    // MARK: - Shared Pieces

    private func row(for contact: ShareableContact, trailingInset: CGFloat = 16) -> some View {
        ContactRowView(
            contact: contact,
            isShared: coordinator.lastSharedContactID == contact.id,
            onQuickShare: {
                coordinator.shareFullContact(contact)
            },
            onCustomizeShare: {
                // Request expanded mode so the sheet has full space
                if coordinator.presentationStyle == .compact {
                    coordinator.requestPresentationStyle(.expanded)
                }
                sheetContact = contact
            }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: trailingInset))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var emptyState: some View {
        if contactManager.authorizationStatus == .limited {
            StatusMessageView(
                systemImage: "person.crop.circle",
                title: "No Contacts Shared",
                message: "Shareable can only see the contacts you allowed. Open the app to choose more.",
                actionTitle: "Open Shareable",
                action: coordinator.openContainingApp
            )
        } else {
            StatusMessageView(
                systemImage: "person.crop.circle",
                title: "No Contacts",
                message: "Contacts saved on this iPhone will appear here."
            )
        }
    }
}
