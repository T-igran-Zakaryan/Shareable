//
//  ShareableContact.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import Foundation
import Contacts
import SwiftUI

/// Represents a labeled item such as a phone number or email address.
public struct ContactLabeledValue: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let rawLabel: String?
    public let value: String

    public init(id: String = UUID().uuidString, label: String, rawLabel: String? = nil, value: String) {
        self.id = id
        self.label = label
        self.rawLabel = rawLabel
        self.value = value
    }
}

/// Represents a postal address.
public struct ContactPostalAddressItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let rawLabel: String?
    public let formattedAddress: String
    public let street: String
    public let city: String
    public let state: String
    public let postalCode: String
    public let country: String

    public init(
        id: String = UUID().uuidString,
        label: String,
        rawLabel: String? = nil,
        formattedAddress: String,
        street: String,
        city: String,
        state: String,
        postalCode: String,
        country: String
    ) {
        self.id = id
        self.label = label
        self.rawLabel = rawLabel
        self.formattedAddress = formattedAddress
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
}

/// A clean, model-level representation of a contact designed for display, searching, and selective sharing.
public struct ShareableContact: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let givenName: String
    public let familyName: String
    public let middleName: String
    public let nickname: String
    public let organizationName: String
    public let jobTitle: String
    public let departmentName: String

    public let phoneNumbers: [ContactLabeledValue]
    public let emailAddresses: [ContactLabeledValue]
    public let postalAddresses: [ContactPostalAddressItem]
    public let thumbnailImageData: Data?
    public let hasImageData: Bool

    /// Primary display name (Full name, or Organization name, or first available detail).
    /// Stored rather than computed: search, sectioning and sorting read it many times per keystroke.
    public let displayName: String

    /// Underlying CNContact retained for full vCard serialization.
    public let underlyingContact: CNContact

    public init(contact: CNContact) {
        self.id = contact.identifier
        self.givenName = contact.givenName
        self.familyName = contact.familyName
        self.middleName = contact.middleName
        self.nickname = contact.nickname
        self.organizationName = contact.organizationName
        self.jobTitle = contact.jobTitle
        self.departmentName = contact.departmentName

        // Phone numbers
        self.phoneNumbers = contact.phoneNumbers.map { labeledValue in
            let rawLabel = labeledValue.label
            let displayLabel: String
            if let raw = rawLabel {
                displayLabel = CNLabeledValue<NSString>.localizedString(forLabel: raw)
            } else {
                displayLabel = "Phone"
            }
            return ContactLabeledValue(
                id: labeledValue.identifier,
                label: displayLabel,
                rawLabel: rawLabel,
                value: labeledValue.value.stringValue
            )
        }

        // Emails
        self.emailAddresses = contact.emailAddresses.map { labeledValue in
            let rawLabel = labeledValue.label
            let displayLabel: String
            if let raw = rawLabel {
                displayLabel = CNLabeledValue<NSString>.localizedString(forLabel: raw)
            } else {
                displayLabel = "Email"
            }
            return ContactLabeledValue(
                id: labeledValue.identifier,
                label: displayLabel,
                rawLabel: rawLabel,
                value: labeledValue.value as String
            )
        }

        // Postal addresses
        self.postalAddresses = contact.postalAddresses.map { labeledValue in
            let rawLabel = labeledValue.label
            let displayLabel: String
            if let raw = rawLabel {
                displayLabel = CNLabeledValue<NSString>.localizedString(forLabel: raw)
            } else {
                displayLabel = "Address"
            }
            let addr = labeledValue.value
            let formatted = CNPostalAddressFormatter.string(from: addr, style: .mailingAddress)
            return ContactPostalAddressItem(
                id: labeledValue.identifier,
                label: displayLabel,
                rawLabel: rawLabel,
                formattedAddress: formatted.replacingOccurrences(of: "\n", with: ", "),
                street: addr.street,
                city: addr.city,
                state: addr.state,
                postalCode: addr.postalCode,
                country: addr.country
            )
        }

        self.thumbnailImageData = contact.thumbnailImageData
        self.hasImageData = contact.imageDataAvailable
        self.underlyingContact = contact
        self.displayName = Self.makeDisplayName(for: contact)
    }

    private static func makeDisplayName(for contact: CNContact) -> String {
        if let formatted = CNContactFormatter.string(from: contact, style: .fullName),
           !formatted.trimmingCharacters(in: .whitespaces).isEmpty {
            return formatted
        }
        if !contact.organizationName.trimmingCharacters(in: .whitespaces).isEmpty {
            return contact.organizationName
        }
        if let firstPhone = contact.phoneNumbers.first?.value.stringValue {
            return firstPhone
        }
        if let firstEmail = contact.emailAddresses.first?.value as String? {
            return firstEmail
        }
        return "Unknown Contact"
    }

    // MARK: - Computed Presentation Properties

    /// Secondary subtitle for contact list (e.g. Job Title at Company, or primary phone number).
    public var subtitle: String? {
        var parts: [String] = []
        if !jobTitle.isEmpty { parts.append(jobTitle) }
        if !organizationName.isEmpty && displayName != organizationName { parts.append(organizationName) }

        if !parts.isEmpty {
            return parts.joined(separator: " • ")
        }
        if let phone = phoneNumbers.first?.value {
            return phone
        }
        if let email = emailAddresses.first?.value {
            return email
        }
        return nil
    }

    /// Initials used for avatar fallback.
    public var initials: String {
        let first = givenName.first.map(String.init) ?? ""
        let last = familyName.first.map(String.init) ?? ""
        let combined = "\(first)\(last)".uppercased()
        if !combined.isEmpty {
            return combined
        }
        if let orgFirst = organizationName.first {
            return String(orgFirst).uppercased()
        }
        return "?"
    }

    /// The first letter of the contact's name for alphabetical indexing (A-Z or #).
    public var sectionIndexKey: String {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard let firstChar = name.first?.uppercased() else { return "#" }
        if firstChar >= "A" && firstChar <= "Z" {
            return firstChar
        }
        return "#"
    }

    /// Checks if this contact matches a given search query string.
    public func matches(query: String) -> Bool {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return true }

        if displayName.localizedCaseInsensitiveContains(clean) { return true }
        if givenName.localizedCaseInsensitiveContains(clean) { return true }
        if familyName.localizedCaseInsensitiveContains(clean) { return true }
        if organizationName.localizedCaseInsensitiveContains(clean) { return true }
        if jobTitle.localizedCaseInsensitiveContains(clean) { return true }

        for phone in phoneNumbers {
            let digitsOnly = phone.value.filter { $0.isNumber }
            let queryDigits = clean.filter { $0.isNumber }
            if phone.value.localizedCaseInsensitiveContains(clean) { return true }
            if !queryDigits.isEmpty && digitsOnly.contains(queryDigits) { return true }
        }

        for email in emailAddresses {
            if email.value.localizedCaseInsensitiveContains(clean) { return true }
        }

        return false
    }

    public static func == (lhs: ShareableContact, rhs: ShareableContact) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
