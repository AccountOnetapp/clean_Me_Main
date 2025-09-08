//
//  ContactModels.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import Foundation
import CoreData

// MARK: - Contact Data Model
struct ContactData: Identifiable, Hashable, Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let email: String?
    let notes: String?
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    init(firstName: String, lastName: String, phoneNumber: String, email: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.email = email
        self.notes = notes
        self.dateAdded = Date()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    init(id: UUID, firstName: String, lastName: String, phoneNumber: String, email: String?, notes: String?, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.email = email
        self.notes = notes
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    var formattedPhoneNumber: String {
        // Basic phone number formatting
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if cleanNumber.count == 11 && cleanNumber.hasPrefix("7") {
            // Russian format: +7 (999) 456-78-90
            let formatted = "+7 (\(cleanNumber.dropFirst().prefix(3))) \(cleanNumber.dropFirst(4).prefix(3))-\(cleanNumber.dropFirst(7).prefix(2))-\(cleanNumber.dropFirst(9))"
            return formatted
        } else if cleanNumber.count == 10 {
            // US format: (999) 456-7890
            let formatted = "(\(cleanNumber.prefix(3))) \(cleanNumber.dropFirst(3).prefix(3))-\(cleanNumber.dropFirst(6))"
            return formatted
        }
        
        return phoneNumber // Return original if can't format
    }
}

// MARK: - Core Data Extensions
// Note: SafeContactEntity extensions are now defined in SafeContactEntity+Extensions.swift
