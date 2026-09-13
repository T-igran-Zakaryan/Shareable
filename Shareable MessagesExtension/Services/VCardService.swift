//
//  VCardService.swift
//  Shareable MessagesExtension
//
//  Created for Shareable iMessage Extension.
//

import Foundation
import Contacts

/// Service responsible for generating and serializing contacts into standard vCard (.vcf) files.
public enum VCardService {

    public enum VCardError: LocalizedError {
        case serializationFailed
        case fileWriteFailed(Error)
        case emptyContact

        public var errorDescription: String? {
            switch self {
            case .serializationFailed:
                return "Failed to convert contact into vCard format."
            case .fileWriteFailed(let error):
                return "Failed to write vCard file to disk: \(error.localizedDescription)"
            case .emptyContact:
                return "The selected contact has no exportable details."
            }
        }
    }

    /// Generates a vCard (.vcf) file for a full contact and returns the local file URL.
    public static func createVCardFile(for contact: ShareableContact) throws -> (url: URL, filename: String) {
        let vCardData: Data
        do {
            vCardData = try CNContactVCardSerialization.data(with: [contact.underlyingContact])
        } catch {
            throw VCardError.serializationFailed
        }

        return try writeVCardData(vCardData, contactName: contact.displayName)
    }

    /// Generates a vCard (.vcf) file containing ONLY the specified subset of fields.
    /// This gives the user complete privacy control over what numbers or addresses they share.
    public static func createFilteredVCardFile(
        for contact: ShareableContact,
        selectedPhoneIDs: Set<String>,
        selectedEmailIDs: Set<String>,
        selectedAddressIDs: Set<String>,
        includePhoto: Bool
    ) throws -> (url: URL, filename: String) {
        let mutableContact = CNMutableContact()

        // Core identity
        mutableContact.givenName = contact.givenName
        mutableContact.familyName = contact.familyName
        mutableContact.middleName = contact.middleName
        mutableContact.nickname = contact.nickname
        mutableContact.organizationName = contact.organizationName
        mutableContact.jobTitle = contact.jobTitle
        mutableContact.departmentName = contact.departmentName

        // Photo
        if includePhoto, let originalImageData = contact.underlyingContact.imageData {
            mutableContact.imageData = originalImageData
        }

        // Filtered Phone Numbers
        let filteredPhones = contact.underlyingContact.phoneNumbers.filter {
            selectedPhoneIDs.contains($0.identifier)
        }
        mutableContact.phoneNumbers = filteredPhones

        // Filtered Email Addresses
        let filteredEmails = contact.underlyingContact.emailAddresses.filter {
            selectedEmailIDs.contains($0.identifier)
        }
        mutableContact.emailAddresses = filteredEmails

        // Filtered Postal Addresses
        let filteredAddresses = contact.underlyingContact.postalAddresses.filter {
            selectedAddressIDs.contains($0.identifier)
        }
        mutableContact.postalAddresses = filteredAddresses

        // Ensure there is at least something to share
        let hasContent = !mutableContact.givenName.isEmpty
            || !mutableContact.familyName.isEmpty
            || !mutableContact.organizationName.isEmpty
            || !mutableContact.phoneNumbers.isEmpty
            || !mutableContact.emailAddresses.isEmpty

        guard hasContent else {
            throw VCardError.emptyContact
        }

        let vCardData: Data
        do {
            vCardData = try CNContactVCardSerialization.data(with: [mutableContact])
        } catch {
            throw VCardError.serializationFailed
        }

        return try writeVCardData(vCardData, contactName: contact.displayName)
    }

    // MARK: - Helper Methods

    private static func writeVCardData(_ data: Data, contactName: String) throws -> (url: URL, filename: String) {
        let sanitized = sanitizeFilename(contactName)
        let uniqueID = UUID().uuidString.prefix(6)
        let filename = "\(sanitized)_\(uniqueID).vcf"
        let displayFilename = "\(sanitized).vcf"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL, options: .atomic)
            return (url: fileURL, filename: displayFilename)
        } catch {
            throw VCardError.fileWriteFailed(error)
        }
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = name.components(separatedBy: validCharacters.inverted).joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Contact" : trimmed
    }
}
