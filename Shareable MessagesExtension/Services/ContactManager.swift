//
//  ContactManager.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import Foundation
import Contacts
import SwiftUI
import Observation

/// Section grouping for contacts in alphabetical display.
public struct ContactSection: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let contacts: [ShareableContact]
}

@Observable
@MainActor
public final class ContactManager {

    // MARK: - Published State

    public var authorizationStatus: CNAuthorizationStatus = .notDetermined
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var contacts: [ShareableContact] = []
    public var searchQuery: String = ""

    public init() {
        self.authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    // MARK: - Authorization and Initial Fetch

    /// Checks the current authorization status and immediately fetches contacts if authorized.
    public func checkAuthorizationAndFetch() {
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
        self.authorizationStatus = currentStatus

        switch currentStatus {
        case .authorized, .limited:
            fetchContacts()
        case .notDetermined, .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Fetching Contacts

    /// Fetches all contacts in the background using the required vCard descriptors to avoid CNPropertyNotFetchedException.
    public func fetchContacts() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task { @concurrent in
            do {
                let fetched = try Self.performBackgroundFetch()
                await self.finishFetch(with: fetched)
            } catch {
                await self.failFetch(with: error)
            }
        }
    }

    private func finishFetch(with fetched: [ShareableContact]) {
        contacts = fetched
        isLoading = false
    }

    private func failFetch(with error: Error) {
        errorMessage = "Unable to load contacts: \(error.localizedDescription)"
        isLoading = false
    }

    /// Performs the heavy contact store enumeration off the main thread.
    private nonisolated static func performBackgroundFetch() throws -> [ShareableContact] {
        let store = CNContactStore()

        // Critical: Must include CNContactVCardSerialization.descriptorForRequiredKeys()
        // so that subsequent serialization never throws an uncaught property exception.
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactVCardSerialization.descriptorForRequiredKeys(),
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .userDefault

        var results: [ShareableContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let model = ShareableContact(contact: contact)
            results.append(model)
        }

        return results
    }

    // MARK: - Filtered and Grouped Results

    /// Contacts filtered by current search query.
    public var filteredContacts: [ShareableContact] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        return contacts.filter { $0.matches(query: query) }
    }

    /// Grouped and alphabetically sorted contact sections (e.g. A, B, C, ..., #).
    public var sectionedContacts: [ContactSection] {
        let items = filteredContacts
        let grouped = Dictionary(grouping: items) { $0.sectionIndexKey }

        let sortedKeys = grouped.keys.sorted { first, second in
            if first == "#" { return false }
            if second == "#" { return true }
            return first < second
        }

        return sortedKeys.map { key in
            let sortedSectionItems = (grouped[key] ?? []).sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return ContactSection(title: key, contacts: sortedSectionItems)
        }
    }
}
