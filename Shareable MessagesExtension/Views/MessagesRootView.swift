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
    /// Set when the detail sheet is what expanded the app, so closing it can collapse back.
    @State private var didExpandForSheet = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isExpanded: Bool {
        coordinator.presentationStyle == .expanded
    }

    /// In landscape on iPhone, Messages only ever presents the app expanded, so a
    /// collapse request is a no-op. Offer to close the app instead.
    private var canCollapse: Bool {
        verticalSizeClass != .compact
    }

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
            .onChange(of: coordinator.isSearchActive) { _, isActive in
                // Let the expanded layout settle first, or the field can't take focus.
                Task {
                    await Task.yield()
                    isSearchFocused = isActive
                }
            }
            .onChange(of: isSearchFocused) { _, isFocused in
                coordinator.isSearchActive = isFocused
            }
            .sheet(item: $sheetContact, onDismiss: restorePresentationAfterSheet) { contact in
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
            contactsView
        default:
            PermissionView(status: contactManager.authorizationStatus, onOpenApp: coordinator.openContainingApp)
        }
    }

    // MARK: - Contacts (same layout in compact and expanded)

    private var contactsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                searchField

                Button(action: togglePresentation) {
                    Label(presentationToggleTitle, systemImage: presentationToggleIcon)
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

            if contactManager.contacts.isEmpty {
                // The first fetch is quick, so show nothing rather than flashing a spinner.
                if !contactManager.isLoading {
                    emptyState
                } else {
                    Spacer()
                }
            } else if contactManager.filteredContacts.isEmpty {
                StatusMessageView(
                    systemImage: "magnifyingglass",
                    title: "No Results",
                    message: "No contacts match \"\(contactManager.searchQuery)\"."
                )
            } else {
                List(contactManager.filteredContacts) { contact in
                    row(for: contact)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }

    // MARK: - Presentation Toggle

    private var presentationToggleTitle: String {
        guard canCollapse else { return "Close" }
        return isExpanded ? "Collapse" : "Show All Contacts"
    }

    private var presentationToggleIcon: String {
        guard canCollapse else { return "xmark" }
        return isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
    }

    /// The sheet expands the app on the user's behalf, so put the drawer back where
    /// it was once the sheet closes. Sharing already collapses on its own.
    /// Portrait only: landscape has no compact drawer to return to.
    private func restorePresentationAfterSheet() {
        guard didExpandForSheet else { return }
        didExpandForSheet = false
        guard canCollapse else { return }
        coordinator.requestPresentationStyle(.compact)
    }

    private func togglePresentation() {
        guard canCollapse else {
            coordinator.dismissExtension()
            return
        }
        coordinator.requestPresentationStyle(isExpanded ? .compact : .expanded)
    }

    /// A real text field when expanded. In compact mode the keyboard can't appear,
    /// so the same-looking pill expands the app with search already focused.
    @ViewBuilder
    private var searchField: some View {
        if isExpanded {
            searchCapsule {
                TextField("Name, phone or email", text: $contactManager.searchQuery)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !contactManager.searchQuery.isEmpty {
                    Button("Clear Search", systemImage: "xmark.circle.fill") {
                        contactManager.searchQuery = ""
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tertiary)
                    .buttonStyle(.plain)
                }
            }
            .onTapGesture {
                isSearchFocused = true
            }
        } else {
            Button(action: coordinator.expandForSearch) {
                searchCapsule {
                    Text("Search")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search Contacts")
        }
    }

    private func searchCapsule(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            content()
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.fill.tertiary, in: .capsule)
        .contentShape(.capsule)
    }

    // MARK: - Shared Pieces

    private func row(for contact: ShareableContact) -> some View {
        ContactRowView(
            contact: contact,
            isShared: coordinator.lastSharedContactID == contact.id,
            onQuickShare: {
                coordinator.shareFullContact(contact)
            },
            onCustomizeShare: {
                // Request expanded mode so the sheet has full space
                if !isExpanded {
                    didExpandForSheet = true
                    coordinator.requestPresentationStyle(.expanded)
                }
                sheetContact = contact
            }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
