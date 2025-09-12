//
//  ContactsView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import CoreData
import Contacts
import ContactsUI
import UIKit

// MARK: - Contact Category Enum
enum ContactCategory: String, CaseIterable {
    case allContacts = "All contacts"
    case duplicates = "Duplicates"
    case incomplete = "Incomplete"
    
    var systemImage: String {
        switch self {
        case .allContacts: return "person.2.fill"
        case .duplicates: return "person.2.badge.minus"
        case .incomplete: return "person.badge.clock"
        }
    }
}



struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @StateObject private var permissionManager = ContactsPermissionManager()
    @Environment(\.dismiss) private var dismiss
    
    // Navigation states
    @State private var showAllContacts = false
    @State private var showDuplicates = false
    @State private var showIncomplete = false
    

    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
                ZStack {
                    CMColor.background
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header
                        headerView(scalingFactor: scalingFactor)
                        
                    // Content based on permission status
                    if !permissionManager.canAccessContacts {
                        permissionRequestView(scalingFactor: scalingFactor)
                    } else if viewModel.isLoading {
                            loadingView(scalingFactor: scalingFactor)
                        } else {
                        // Main content with three category buttons
                        ScrollView {
                            VStack(spacing: 16 * scalingFactor) {
                                // Contact categories
                                ForEach(ContactCategory.allCases, id: \.self) { category in
                                    contactCategoryButton(
                                        category: category,
                                        scalingFactor: scalingFactor
                                    )
                                }
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.top, 24 * scalingFactor)
                            .padding(.bottom, 32 * scalingFactor)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAllContacts) {
            AllContactsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showDuplicates) {
            DuplicateContactsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showIncomplete) {
            IncompleteContactsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            // Always scan for contacts and duplicates when screen appears
            await performContactsScan()
        }
        .onChange(of: permissionManager.authorizationStatus) { newStatus in
            if newStatus == .authorized {
                Task {
                    await performContactsScan()
                }
            }
        }
        .onAppear {
            // Also scan when returning to this screen
            Task {
                await performContactsScan()
            }
        }
    }
    
    // MARK: - Header View
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            // Left side - Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primary)
                }
            }
            .frame(width: 80 * scalingFactor, alignment: .leading)
            
            Spacer()
            
            // Center - Title and status
            VStack(spacing: 4 * scalingFactor) {
            Text("Contacts")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
                if viewModel.isLoading {
                    HStack(spacing: 4 * scalingFactor) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                            .scaleEffect(0.6)
                        
                        Text("Scanning...")
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                } else if !viewModel.duplicateGroups.isEmpty {
                    let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                    Text("\(viewModel.duplicateGroups.count) groups • \(totalDuplicates) duplicates")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.error)
                } else if !viewModel.systemContacts.isEmpty {
                    Text("\(viewModel.systemContacts.count) contacts • No duplicates")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.success)
                }
            }
            
            Spacer()
            
            // Right side - Refresh button
            Button(action: {
                Task {
                    await performContactsScan()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
                    .rotationEffect(viewModel.isLoading ? Angle(degrees: 360) : Angle(degrees: 0))
                    .animation(viewModel.isLoading ? 
                              Animation.linear(duration: 1).repeatForever(autoreverses: false) : 
                              .default, value: viewModel.isLoading)
            }
            .disabled(viewModel.isLoading)
            .frame(width: 80 * scalingFactor, alignment: .trailing)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 20 * scalingFactor)
    }
    
    // MARK: - Contact Category Button
    private func contactCategoryButton(category: ContactCategory, scalingFactor: CGFloat) -> some View {
        Button(action: {
            switch category {
            case .allContacts:
            showAllContacts = true
            case .duplicates:
                showDuplicates = true
            case .incomplete:
                showIncomplete = true
            }
        }) {
            HStack(spacing: 16 * scalingFactor) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 56 * scalingFactor, height: 56 * scalingFactor)
                    
                    Image(systemName: category.systemImage)
                        .font(.system(size: 24 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text(category.rawValue)
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    
                    Text(getSubtitleForCategory(category))
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
                
                // Count and chevron
                VStack(alignment: .trailing, spacing: 4 * scalingFactor) {
                    Text(getCountForCategory(category))
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.vertical, 16 * scalingFactor)
            .background(
                RoundedRectangle(cornerRadius: 16 * scalingFactor)
                    .fill(CMColor.surface)
                    .shadow(color: .black.opacity(0.05), radius: 4 * scalingFactor, x: 0, y: 2 * scalingFactor)
            )
        }
    }
    
    // MARK: - Helper Methods for Category Info
    private func getSubtitleForCategory(_ category: ContactCategory) -> String {
        switch category {
        case .allContacts:
            return "View and manage all contacts"
        case .duplicates:
            return "Find and merge duplicate contacts"
        case .incomplete:
            return "Contacts missing information"
        }
    }
    
    private func getCountForCategory(_ category: ContactCategory) -> String {
        switch category {
        case .allContacts:
            return "\(viewModel.systemContacts.count)"
        case .duplicates:
            let duplicateCount = viewModel.duplicateGroups.flatMap { $0 }.count
            return "\(duplicateCount)"
        case .incomplete:
            let incompleteCount = viewModel.systemContacts.filter { isIncompleteContact($0) }.count
            return "\(incompleteCount)"
        }
    }
    
    private func isIncompleteContact(_ contact: CNContact) -> Bool {
        // Контакт считается незавершенным если отсутствует имя ИЛИ номер телефона
        let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
        let hasPhone = !contact.phoneNumbers.isEmpty
        
        return !hasName || !hasPhone
    }
    

    
    // MARK: - Permission Request View
    private func permissionRequestView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
                Spacer()
                
            VStack(spacing: 16 * scalingFactor) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 64 * scalingFactor))
                    .foregroundColor(CMColor.primary)
                
                VStack(spacing: 8 * scalingFactor) {
                    Text("Access to Contacts")
                        .font(.system(size: 24 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("To find and merge duplicate contacts, we need access to your contacts")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scalingFactor)
                }
                
                    Button(action: {
                    requestContactsPermission()
                }) {
                    Text(permissionManager.shouldRedirectToSettings ? "Open Settings" : "Allow Access")
                        .font(.system(size: 17 * scalingFactor, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50 * scalingFactor)
                        .background(CMColor.primary)
                        .cornerRadius(12 * scalingFactor)
                }
                .padding(.horizontal, 32 * scalingFactor)
                .padding(.top, 16 * scalingFactor)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 16 * scalingFactor)
            
            Text("Loading contacts...")
                .font(.system(size: 16 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
            
            Spacer()
        }
    }
    


    
    // MARK: - Contacts Scanning
    private func performContactsScan() async {
        // Check permission first
        permissionManager.checkAuthorizationStatus()
        
        guard permissionManager.canAccessContacts else {
            return // Permission view will be shown
        }
        
        // Load and scan system contacts
        await viewModel.loadSystemContacts()
    }
    
    // MARK: - Helper Methods
    private func requestContactsPermission() {
        if permissionManager.shouldRedirectToSettings {
            permissionManager.openAppSettings()
        } else {
            Task {
                await permissionManager.requestAccess()
            }
        }
    }
}

// MARK: - Duplicate Contacts View
struct DuplicateContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State for duplicates management
    @State private var selectedDuplicates: Set<String> = []
    @State private var showMergeAlert = false
    @State private var isPerformingMerge = false
    @State private var mergeSuccessMessage: String?
    @State private var showMergeSuccess = false
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 6 * scalingFactor) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.primary)
                                
                                Text("Back")
                                    .font(.system(size: 17 * scalingFactor, weight: .regular))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                        .frame(width: 80 * scalingFactor, alignment: .leading)
                        
                        Spacer()
                        
                        VStack(spacing: 4 * scalingFactor) {
                            Text("Duplicates")
                                .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if !viewModel.duplicateGroups.isEmpty {
                                let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                                Text("\(viewModel.duplicateGroups.count) groups • \(totalDuplicates) duplicates")
                                    .font(.system(size: 12 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.error)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await viewModel.loadSystemContacts()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.primary)
                        }
                        .frame(width: 80 * scalingFactor, alignment: .trailing)
                    }
                    .padding(.horizontal, 16 * scalingFactor)
                    .padding(.bottom, 20 * scalingFactor)
                    
                    // Content
                    if viewModel.duplicateGroups.isEmpty {
                        noDuplicatesFoundView(scalingFactor: scalingFactor)
                    } else {
                        ScrollView {
                            VStack(spacing: 24 * scalingFactor) {
                                ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { index, group in
                                    duplicateGroupSection(
                                        group: group,
                                        groupIndex: index,
                                        scalingFactor: scalingFactor,
                                        isFirstGroup: index == 0
                                    )
                                }
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.bottom, 32 * scalingFactor)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Merge Contacts", isPresented: $showMergeAlert) {
            Button("Merge") {
                mergeSelectedContacts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to merge the selected duplicate contacts?")
        }
        .alert("Success", isPresented: $showMergeSuccess) {
            Button("OK") { 
                mergeSuccessMessage = nil
            }
        } message: {
            Text(mergeSuccessMessage ?? "Contacts merged successfully")
        }
    }
    
    // MARK: - Helper Methods
    private func toggleSelection(for id: String) {
        if selectedDuplicates.contains(id) {
            selectedDuplicates.remove(id)
        } else {
            selectedDuplicates.insert(id)
        }
    }
    
    private func toggleSelectAll(for group: [CNContact]?) {
        guard let group = group else { return }
        
        let groupIds = group.map { $0.identifier }
        let areAllSelected = groupIds.allSatisfy { selectedDuplicates.contains($0) }
        
        if areAllSelected {
            groupIds.forEach { selectedDuplicates.remove($0) }
        } else {
            groupIds.forEach { selectedDuplicates.insert($0) }
        }
    }
    
    private func mergeSelectedContacts() {
        // Implementation for merging contacts
        print("Merging contacts: \(selectedDuplicates)")
        selectedDuplicates.removeAll()
    }
    
    private func mergeSelectedContactsInGroup(_ group: [CNContact]) {
        let selectedInGroup = group.filter { selectedDuplicates.contains($0.identifier) }
        let selectedIds = Set(selectedInGroup.map { $0.identifier })
        
        guard selectedInGroup.count >= 2 else {
            viewModel.errorMessage = "Please select at least 2 contacts to merge"
            return
        }
        
        Task {
            isPerformingMerge = true
            
            let success = await viewModel.mergeContactGroup(group, selectedIds: selectedIds)
            
            await MainActor.run {
                isPerformingMerge = false
                
                if success {
                    // Clear selection for merged contacts
                    selectedIds.forEach { selectedDuplicates.remove($0) }
                    
                    // Show success message
                    mergeSuccessMessage = "Successfully merged \(selectedInGroup.count) contacts"
                    showMergeSuccess = true
                    
                    // Reload contacts and rescan for duplicates
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                } else {
                    // Error message is already set in viewModel.errorMessage
                }
            }
        }
    }
    
    // MARK: - Duplicate Group Section
    private func duplicateGroupSection(group: [CNContact], groupIndex: Int, scalingFactor: CGFloat, isFirstGroup: Bool) -> some View {
        let firstContact = group.first!
        let selectedInGroup = group.filter { selectedDuplicates.contains($0.identifier) }.count
        
        return VStack(spacing: 16 * scalingFactor) {
            // Group header with enhanced styling
            VStack(spacing: 12 * scalingFactor) {
                HStack {
                    // Enhanced circle with initial
            ZStack {
                Circle()
                            .fill(isFirstGroup ? CMColor.primary : CMColor.secondary)
                            .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                        
                        Text(String(firstContact.givenName.prefix(1).uppercased()))
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                        HStack {
                            Text(isFirstGroup ? "Duplicates" : "Group \(groupIndex + 1)")
                                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                            // Duplicate count badge
                            Text("\(group.count)")
                                .font(.system(size: 12 * scalingFactor, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6 * scalingFactor)
                                .padding(.vertical, 2 * scalingFactor)
                                .background(CMColor.error)
                                .cornerRadius(8 * scalingFactor)
                        }
                        
                        let fullName = "\(firstContact.givenName) \(firstContact.familyName)"
                        Text(fullName.count > 25 ? String(fullName.prefix(22)) + "..." : fullName)
                            .font(.system(size: 15 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                        
                        if let phoneNumber = firstContact.phoneNumbers.first?.value.stringValue {
                            Text(phoneNumber)
                                .font(.system(size: 15 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if selectedInGroup > 0 {
                        VStack {
                            Text("\(selectedInGroup)/\(group.count)")
                                .font(.system(size: 12 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                            
                            Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16 * scalingFactor))
                                .foregroundColor(CMColor.primary)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
                    }
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.vertical, 12 * scalingFactor)
                .background(
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .fill(CMColor.surface)
                        .shadow(color: .black.opacity(0.05), radius: 2 * scalingFactor, x: 0, y: 1 * scalingFactor)
                )
            }
            
            // Controls section
            HStack {
                Text("Select contacts to merge")
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                
                Spacer()
                
                    Button(action: {
                    toggleSelectAll(for: group)
                }) {
                    Text(selectedInGroup == group.count ? "Deselect all" : "Select all")
                        .font(.system(size: 15 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            
            // Contact cards with enhanced display
            VStack(spacing: 8 * scalingFactor) {
                ForEach(Array(group.enumerated()), id: \.element.identifier) { index, contact in
                    enhancedDuplicateContactCard(
                        contact: contact,
                        isSelected: selectedDuplicates.contains(contact.identifier),
                        isPrimary: index == 0, // First contact is most complete
                        scalingFactor: scalingFactor
                    )
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            
            // Group merge button
            if selectedInGroup >= 2 {
                    Button(action: {
                    mergeSelectedContactsInGroup(group)
                }) {
                    HStack {
                        if isPerformingMerge {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 16 * scalingFactor, weight: .medium))
                        }
                            
                        Text(isPerformingMerge ? "Merging..." : "Merge \(selectedInGroup) contacts")
                            .font(.system(size: 17 * scalingFactor, weight: .semibold))
                        }
                    .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    .frame(height: 48 * scalingFactor)
                    .background(isPerformingMerge ? CMColor.primary.opacity(0.7) : CMColor.primary)
                    .cornerRadius(12 * scalingFactor)
                }
                .disabled(isPerformingMerge)
                .animation(.easeInOut(duration: 0.2), value: isPerformingMerge)
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.top, 8 * scalingFactor)
            }
        }
        .padding(.vertical, 8 * scalingFactor)
    }
    
    // MARK: - Enhanced Contact Card
    private func enhancedDuplicateContactCard(contact: CNContact, isSelected: Bool, isPrimary: Bool, scalingFactor: CGFloat) -> some View {
        Button(action: {
            toggleSelection(for: contact.identifier)
        }) {
            HStack(spacing: 12 * scalingFactor) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 2)
                        .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                    
                    if isSelected {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10 * scalingFactor, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Contact info
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    HStack {
                        Text("\(contact.givenName) \(contact.familyName)")
                            .font(.system(size: 16 * scalingFactor, weight: isPrimary ? .semibold : .regular))
                            .foregroundColor(CMColor.primaryText)
                        
                        if isPrimary {
                            Text("RECOMMENDED")
                                .font(.system(size: 10 * scalingFactor, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6 * scalingFactor)
                                .padding(.vertical, 2 * scalingFactor)
                                .background(CMColor.success)
                                .cornerRadius(4 * scalingFactor)
                        }
                    }
                    
                    if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                        Text(phoneNumber)
                            .font(.system(size: 14 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    if let email = contact.emailAddresses.first?.value as? String {
                        Text(email)
                            .font(.system(size: 14 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    // Additional info indicators
                    HStack(spacing: 8 * scalingFactor) {
                        if contact.phoneNumbers.count > 1 {
                            Label("\(contact.phoneNumbers.count)", systemImage: "phone")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                        }
                        
                        if !contact.emailAddresses.isEmpty {
                            Label("\(contact.emailAddresses.count)", systemImage: "envelope")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                        }
                        
                        if !contact.organizationName.isEmpty {
                            Label(contact.organizationName, systemImage: "building")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 12 * scalingFactor)
            .background(
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(isSelected ? CMColor.primary.opacity(0.05) : CMColor.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * scalingFactor)
                            .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - No Duplicates Found View
    private func noDuplicatesFoundView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48 * scalingFactor))
                .foregroundColor(CMColor.success)
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No Duplicates Found")
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("All your contacts are unique. Great job keeping your contacts organized!")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
        }
        .padding(.vertical, 48 * scalingFactor)
    }
}

// MARK: - Incomplete Contacts View
struct IncompleteContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(CMColor.primary)
                    
                    Spacer()
                    
                    Text("Incomplete")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("") { }
                        .disabled(true)
                        .opacity(0)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Name, number, company or email", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // Content
                if incompleteContacts.isEmpty {
                    // Empty State
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("All Contacts Complete")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("All your contacts have complete information. Great job keeping your contacts organized!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
        } else {
                    // Contacts List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredIncompleteContacts.enumerated()), id: \.element.identifier) { index, contact in
                                NavigationLink(destination: ContactCardPushView(contact: contact)) {
                                    IncompleteContactRow(contact: contact)
                                        .background(Color(.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Добавляем разделитель между ячейками
                                if index < filteredIncompleteContacts.count - 1 {
                                    Divider()
                                        .background(Color(.separator))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Computed Properties
    private var incompleteContacts: [CNContact] {
        return viewModel.systemContacts.filter { contact in
            let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
            let hasPhone = !contact.phoneNumbers.isEmpty
            
            // Контакт незавершен если отсутствует имя ИЛИ телефон
            return !hasName || !hasPhone
        }
    }
    
    private var filteredIncompleteContacts: [CNContact] {
        let contacts = searchText.isEmpty ? incompleteContacts : incompleteContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: " ")
            let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: " ")
            let company = contact.organizationName
            
            let searchQuery = searchText.lowercased()
            
            return fullName.lowercased().contains(searchQuery) ||
                   phoneNumbers.lowercased().contains(searchQuery) ||
                   emails.lowercased().contains(searchQuery) ||
                   company.lowercased().contains(searchQuery)
        }
        
        return contacts.sorted { 
            let name1 = "\($0.givenName) \($0.familyName)".trimmingCharacters(in: .whitespaces)
            let name2 = "\($1.givenName) \($1.familyName)".trimmingCharacters(in: .whitespaces)
            
            // Если у контакта нет имени, ставим его в конец
            if name1.isEmpty && !name2.isEmpty { return false }
            if !name1.isEmpty && name2.isEmpty { return true }
            if name1.isEmpty && name2.isEmpty { return false }
            
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
}

// MARK: - Incomplete Contact Row View
private struct IncompleteContactRow: View {
    let contact: CNContact
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Name
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                Text(fullName.isEmpty ? "No Name" : fullName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                // Additional info
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    Text(phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let email = contact.emailAddresses.first?.value as? String {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}





// MARK: - All Contacts View
struct AllContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedContacts: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    @State private var selectedContactForNavigation: CNContact?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let scalingFactor = geometry.size.height / 844
                
                ZStack {
                    CMColor.background
                        .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
            Button(action: {
                            if isSelectionMode {
                                isSelectionMode = false
                                selectedContacts.removeAll()
                            } else {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 6 * scalingFactor) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.primary)
                                
                                Text(isSelectionMode ? "Cancel" : "Back")
                                    .font(.system(size: 17 * scalingFactor, weight: .regular))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2 * scalingFactor) {
                            Text(isSelectionMode ? "Select Contacts" : "Contacts")
                                .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if isSelectionMode && !selectedContacts.isEmpty {
                                Text("\(selectedContacts.count) selected")
                                    .font(.system(size: 12 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if isSelectionMode {
                                if selectedContacts.isEmpty {
                                    // Select all
                                    selectedContacts = Set(filteredSystemContacts.map { $0.identifier })
                                } else {
                                    // Deselect all
                                    selectedContacts.removeAll()
                                }
                            } else {
                                isSelectionMode = true
                            }
                        }) {
                            Text(isSelectionMode ? 
                                 (selectedContacts.isEmpty ? "All" : "None") : 
                                 "Select")
                                .font(.system(size: 17 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primary)
                        }
                    }
                    .padding(.horizontal, 16 * scalingFactor)
                    .padding(.top, 8 * scalingFactor)
                    .padding(.bottom, 20 * scalingFactor)
                    
                    // Search Bar
                HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(CMColor.secondaryText)
                                .font(.system(size: 16 * scalingFactor, weight: .medium))
                            
                            TextField("Search", text: $searchText)
                                .font(.system(size: 16 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primaryText)
                            
                            Spacer()
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(CMColor.secondaryText)
                                        .font(.system(size: 16 * scalingFactor))
                                }
                            }
                        }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.vertical, 12 * scalingFactor)
                        .background(CMColor.backgroundSecondary)
                .cornerRadius(12 * scalingFactor)
            }
                    .padding(.horizontal, 16 * scalingFactor)
                    .padding(.bottom, 20 * scalingFactor)
            
                    // Delete button (visible when contacts are selected)
                    if isSelectionMode && !selectedContacts.isEmpty {
            Button(action: {
                            showDeleteAlert = true
            }) {
                HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                                Text("Delete \(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s")")
                        .font(.system(size: 17 * scalingFactor, weight: .semibold))
                }
                        .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                            .frame(height: 48 * scalingFactor)
                            .background(CMColor.error)
                .cornerRadius(12 * scalingFactor)
            }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.bottom, 16 * scalingFactor)
                    }
                    
                                            // Contacts List with Sections
                        ScrollView {
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(sortedSectionKeys, id: \.self) { sectionKey in
                                    Section {
                                        if let contactsInSection = groupedContacts[sectionKey] {
                                            ForEach(Array(contactsInSection.enumerated()), id: \.element.identifier) { index, contact in
                                                if isSelectionMode {
                                                    SelectableSystemContactRowView(
                                                        contact: contact,
                                                        isSelected: selectedContacts.contains(contact.identifier),
                                                        isSelectionMode: isSelectionMode,
                                                        scalingFactor: scalingFactor,
                                                        onTap: {
                                                            toggleContactSelection(contact.identifier)
                                                        }
                                                    )
                                                } else {
                                                    NavigationLink(
                                                        destination: ContactCardPushView(contact: contact),
                                                        label: {
                                                            SystemContactRowView(contact: contact, scalingFactor: scalingFactor)
                                                        }
                                                    )
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                                
                                                if index < contactsInSection.count - 1 {
                                                    Divider()
                                                        .background(CMColor.border)
                                                        .padding(.horizontal, 16 * scalingFactor)
                                                }
                                            }
                                        }
                                    } header: {
                                        // Section Header
                                        HStack {
                                            Text(sectionKey)
                                                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                                                .foregroundColor(CMColor.secondaryText)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16 * scalingFactor)
                                        .padding(.vertical, 8 * scalingFactor)
                                        .background(CMColor.background)
                                    }
                                }
                            }
                        }
                }
            }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Configure navigation bar for better back button spacing
            UINavigationBar.appearance().backIndicatorImage = UIImage(systemName: "chevron.left")
            UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage(systemName: "chevron.left")
            UINavigationBar.appearance().layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
        .alert("Delete Contacts", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSelectedContacts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s") from your device?")
        }
    }
    
    // MARK: - Helper Methods
    private func toggleContactSelection(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }
    

    
    private func deleteSelectedContacts() {
        Task {
            let contactsToDelete = filteredSystemContacts.filter { selectedContacts.contains($0.identifier) }
            
            let success = await viewModel.deleteContacts(contactsToDelete)
            
            await MainActor.run {
                if success {
                    selectedContacts.removeAll()
                    isSelectionMode = false
                    // Reload contacts
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                }
            }
        }
    }
    
    private var filteredSystemContacts: [CNContact] {
        if searchText.isEmpty {
            return viewModel.systemContacts.sorted { 
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        } else {
            return viewModel.systemContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined()
                return fullName.localizedCaseInsensitiveContains(searchText) ||
                       phoneNumbers.contains(searchText)
            }.sorted { 
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
    
    private var groupedContacts: [String: [CNContact]] {
        Dictionary(grouping: filteredSystemContacts) { contact in
            let firstName = contact.givenName.isEmpty ? contact.familyName : contact.givenName
            let firstLetter = String(firstName.prefix(1)).uppercased()
            return firstLetter.isEmpty ? "#" : firstLetter
        }
    }
    
    private var sortedSectionKeys: [String] {
        groupedContacts.keys.sorted { key1, key2 in
            // Put # at the end
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
}

// MARK: - Contact Row View
struct ContactRowView: View {
    let contact: ContactData
    let scalingFactor: CGFloat
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            // Contact Initial Circle
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                Text(contact.initials)
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text(contact.fullName)
                    .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(contact.formattedPhoneNumber)
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - System Contact Row View
struct SystemContactRowView: View {
    let contact: CNContact
    let scalingFactor: CGFloat
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            // Contact Initial Circle
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                Text(String(contact.givenName.prefix(1)).uppercased())
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text("\(contact.givenName) \(contact.familyName)")
                    .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    Text(phoneNumber)
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Selectable System Contact Row View
struct SelectableSystemContactRowView: View {
    let contact: CNContact
    let isSelected: Bool
    let isSelectionMode: Bool
    let scalingFactor: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16 * scalingFactor) {
                // Selection indicator (if in selection mode)
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 2)
                            .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                        
                        if isSelected {
                            Circle()
                                .fill(CMColor.primary)
                                .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10 * scalingFactor, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Contact Initial Circle
                ZStack {
                    Circle()
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                    
                    Text(String(contact.givenName.prefix(1)).uppercased())
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                }
                
                // Contact Info
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text("\(contact.givenName) \(contact.familyName)")
                        .font(.system(size: 17 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                        Text(phoneNumber)
                            .font(.system(size: 15 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 16 * scalingFactor)
            .background(isSelected ? CMColor.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contact Card Push View (for Navigation)
struct ContactCardPushView: View {
    let contact: CNContact
    @State private var fullContact: CNContact?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading contact...")
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Failed to load contact")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let fullContact = fullContact {
                ContactCardWithCustomNavView(contact: fullContact)
            } else {
                Text("Contact not found")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadFullContact()
        }
    }
    
    private func loadFullContact() async {
        do {
            let store = CNContactStore()
            var keysToFetch = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactIdentifierKey,
                CNContactOrganizationNameKey,
                CNContactJobTitleKey,
                CNContactPostalAddressesKey,
                CNContactImageDataKey,
                CNContactThumbnailImageDataKey
            ] as [CNKeyDescriptor]
            keysToFetch.append(CNContactViewController.descriptorForRequiredKeys())
            
            let loadedContact = try store.unifiedContact(
                withIdentifier: contact.identifier,
                keysToFetch: keysToFetch
            )
            
            await MainActor.run {
                self.fullContact = loadedContact
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}

// MARK: - Contact Card with Custom Navigation
struct ContactCardWithCustomNavView: View {
    let contact: CNContact
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(CMColor.primary)
                        
                        Text("Contacts")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(CMColor.primary)
                    }
                }
                .padding(.leading, 16)
                
                Spacer()
            
                            Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(CMColor.primary)
                .padding(.trailing, 16)
            }
            .frame(height: 44)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .bottom
            )
            
            // Contact View Controller
            ContactCardPushViewRepresentable(contact: contact, isEditing: $isEditing)
                .navigationBarHidden(true)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Contact Card Push View Representable
struct ContactCardPushViewRepresentable: UIViewControllerRepresentable {
    let contact: CNContact
    @Binding var isEditing: Bool
    
    func makeUIViewController(context: Context) -> CNContactViewController {
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsEditing = true
        contactViewController.allowsActions = true
        
        // Hide the default navigation bar since we have custom one
        contactViewController.navigationItem.hidesBackButton = true
        contactViewController.navigationItem.leftBarButtonItem = nil
        contactViewController.navigationItem.rightBarButtonItem = nil
        contactViewController.navigationItem.title = ""
        
        return contactViewController
    }
    
    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {
        // Update editing state when binding changes
        if uiViewController.isEditing != isEditing {
            uiViewController.setEditing(isEditing, animated: true)
        }
    }
}

// MARK: - Contact Card View (for Sheet presentation)
struct ContactCardView: UIViewControllerRepresentable {
    let contact: CNContact
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsEditing = true
        contactViewController.allowsActions = true
        
        // Add cancel and done buttons to dismiss the view
        contactViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(context.coordinator.dismissView)
        )
        
        contactViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(context.coordinator.dismissView)
        )
        
        let navigationController = UINavigationController(rootViewController: contactViewController)
        navigationController.navigationBar.prefersLargeTitles = false
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject {
        private let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        @objc func dismissView() {
            onDismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    ContactsView()
}
