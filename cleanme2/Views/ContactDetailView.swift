//
//  ContactDetailView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import ContactsUI
import Contacts

struct ContactDetailView: UIViewControllerRepresentable {
    let contactData: ContactData
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> CNContactViewController {
        // Create a CNContact from our ContactData
        let contact = createCNContact(from: contactData)
        
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.delegate = context.coordinator
        contactViewController.allowsEditing = false
        contactViewController.allowsActions = true
        
        // Wrap in navigation controller
        let navigationController = UINavigationController(rootViewController: contactViewController)
        
        return contactViewController
    }
    
    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createCNContact(from contactData: ContactData) -> CNContact {
        let contact = CNMutableContact()
        
        contact.givenName = contactData.firstName
        contact.familyName = contactData.lastName
        
        // Add phone number
        if !contactData.phoneNumber.isEmpty {
            let phoneNumber = CNPhoneNumber(stringValue: contactData.phoneNumber)
            let labeledPhoneNumber = CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber)
            contact.phoneNumbers = [labeledPhoneNumber]
        }
        
        // Add email if available
        if let email = contactData.email, !email.isEmpty {
            let labeledEmail = CNLabeledValue(label: CNLabelHome, value: email as NSString)
            contact.emailAddresses = [labeledEmail]
        }
        
        // Add notes if available
        if let notes = contactData.notes, !notes.isEmpty {
            contact.note = notes
        }
        
        return contact
    }
    
    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let parent: ContactDetailView
        
        init(_ parent: ContactDetailView) {
            self.parent = parent
        }
        
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            parent.isPresented = false
        }
        
        func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
            return true
        }
    }
}

struct ContactDetailSheetView: View {
    let contactData: ContactData
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ContactDetailView(contactData: contactData, isPresented: $isPresented)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}
