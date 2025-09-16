//
//  SafeStorageView.swift
//  cleanme2
//
//  Created by Kirill Maximchik on 13.08.25.
//

import SwiftUI

struct SafeStorageView: View {
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @FocusState private var isSearchFocused: Bool
    @State private var showPhotosView: Bool = false
    @State private var showVideosView: Bool = false
    @State private var showContactsView: Bool = false
    @State private var showDocumentsView: Bool = false
    @Binding var isPaywallPresented: Bool

    private let purchaseService = ApphudPurchaseService()

    var hasActiveSubscription: Bool {
        purchaseService.hasActiveSubscription
    }
    
    // Dynamic categories based on storage counts
    private var categories: [SafeStorageCategory] {
        let photosCount = safeStorageManager.getPhotosCount()
        let documentsCount = safeStorageManager.getDocumentsCount()
        let videosCount = safeStorageManager.getVideosCount()
        let contactsCount = safeStorageManager.getContactsCount()
        
        return [
            SafeStorageCategory(
                title: "Docs",
                count: documentsCount == 0 ? "No files" : "\(documentsCount) \(documentsCount == 1 ? "file" : "files")",
                icon: "folder.fill",
                color: CMColor.primary
            ),
            SafeStorageCategory(
                title: "Photos",
                count: photosCount == 0 ? "No files" : "\(photosCount) \(photosCount == 1 ? "file" : "files")",
                icon: "photo.fill",
                color: CMColor.primary
            ),
            SafeStorageCategory(
                title: "Video",
                count: videosCount == 0 ? "No files" : "\(videosCount) \(videosCount == 1 ? "file" : "files")",
                icon: "video.fill", 
                color: CMColor.primary
            ),
            SafeStorageCategory(
                title: "Contacts",
                count: contactsCount == 0 ? "No items" : "\(contactsCount) \(contactsCount == 1 ? "item" : "items")",
                icon: "person.fill",
                color: CMColor.primary
            )
        ]
    }
    
    // Dynamic recent files from storage
    private var recentFiles: [SafeStorageFile] {
        var files: [SafeStorageFile] = []
        
        // Add recent photos
        let recentPhotos = safeStorageManager.getRecentPhotos(limit: 2)
        files.append(contentsOf: recentPhotos.map { photo in
            SafeStorageFile(
                name: photo.fileName,
                icon: "photo.fill"
            )
        })
        
        return Array(files.prefix(5)) // Limit to 5 items max
    }
    
    private func getDocumentIcon(for fileExtension: String?) -> String {
        guard let ext = fileExtension?.lowercased() else { return "doc.fill" }
        
        switch ext {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "rectangle.fill.on.rectangle.fill"
        default:
            return "doc.fill"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844 // Standard iPhone scaling
            
            VStack(spacing: 0) {
                // Header
                headerView(scalingFactor: scalingFactor)
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24 * scalingFactor) {
                        // Search bar
                        searchBar(scalingFactor: scalingFactor)
                        
                        // Content section with conditional display
                        if !isSearchFocused || !searchText.isEmpty {
                            // Category cards
                            categoryCardsView(scalingFactor: scalingFactor)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            // Last added section
                            lastAddedSection(scalingFactor: scalingFactor)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Dynamic bottom spacing based on search state
                        Spacer(minLength: isSearchFocused ? 200 * scalingFactor : 100 * scalingFactor)
                    }
                    .padding(.horizontal, 20 * scalingFactor)
                    .padding(.top, 20 * scalingFactor)
                    .animation(.easeInOut(duration: 0.3), value: isSearchFocused)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            if !hasActiveSubscription {
                isPaywallPresented = true
            } else {
                // Dismiss keyboard when tapping outside
                isSearchFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showPhotosView) {
            MainPhotosView()
        }
        .fullScreenCover(isPresented: $showVideosView) {
            VideosView()
                .environmentObject(safeStorageManager)
        }
        .fullScreenCover(isPresented: $showContactsView) {
            SafeContactsView()
        }
        .fullScreenCover(isPresented: $showDocumentsView) {
            DocumentsView()
                .environmentObject(safeStorageManager)
        }
    }
    
    // MARK: - Header
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Text("Safe storage")
                .font(.system(size: 22 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 10 * scalingFactor)
        .padding(.bottom, 10 * scalingFactor)
        .background(CMColor.background)
    }
    
    // MARK: - Search Bar
    private func searchBar(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            HStack(spacing: 8 * scalingFactor) {
                TextField("Search", text: $searchText)
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        // Handle search submission
                        isSearchFocused = false
                    }
                
                Spacer()
                
                if isSearchFocused && !searchText.isEmpty {
                    Button(action: {
                        if !hasActiveSubscription {
                            isPaywallPresented = true
                        } else {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                            .font(.system(size: 16 * scalingFactor))
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.secondaryText)
                        .font(.system(size: 16 * scalingFactor))
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 12 * scalingFactor)
            .background(CMColor.surface)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(isSearchFocused ? CMColor.primary.opacity(0.3) : CMColor.secondaryText.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    // MARK: - Category Cards
    private func categoryCardsView(scalingFactor: CGFloat) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12 * scalingFactor),
            GridItem(.flexible(), spacing: 12 * scalingFactor)
        ], spacing: 12 * scalingFactor) {
            ForEach(categories) { category in
                categoryCard(category: category, scalingFactor: scalingFactor)
                    .onTapGesture {
                        if !hasActiveSubscription {
                            isPaywallPresented = true
                        } else {
                            if category.title == "Docs" {
                                showDocumentsView = true
                            } else if category.title == "Photos" {
                                showPhotosView = true
                            } else if category.title == "Video" {
                                showVideosView = true
                            } else if category.title == "Contacts" {
                                showContactsView = true
                            }
                        }
                    }
            }
        }
    }
    
    private func categoryCard(category: SafeStorageCategory, scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scalingFactor) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .fill(category.color.opacity(0.1))
                    .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                
                Image(systemName: category.icon)
                    .font(.system(size: 20 * scalingFactor, weight: .medium))
                    .foregroundColor(category.color)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text(category.title)
                    .font(.system(size: 16 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(category.count)
                    .font(.system(size: 12 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(16 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 16 * scalingFactor)
                .stroke(CMColor.secondaryText.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: CMColor.black.opacity(0.02), radius: 8 * scalingFactor, x: 0, y: 2 * scalingFactor)
    }
    
    // MARK: - Last Added Section
    private func lastAddedSection(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            HStack {
                Text("Last added")
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                if !recentFiles.isEmpty {
                    Text("Swipe left to delete")
                        .font(.system(size: 12 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            if recentFiles.isEmpty {
                // Empty state for recent files
                VStack(spacing: 12 * scalingFactor) {
                    Text("No recent files")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .padding(.vertical, 20 * scalingFactor)
                }
                .frame(maxWidth: .infinity)
                .background(CMColor.surface)
                .cornerRadius(16 * scalingFactor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16 * scalingFactor)
                        .stroke(CMColor.secondaryText.opacity(0.05), lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentFiles.enumerated()), id: \.element.id) { index, file in
                        fileRow(file: file, scalingFactor: scalingFactor)
                        
                        if index < recentFiles.count - 1 {
                            Divider()
                                .background(CMColor.secondaryText.opacity(0.1))
                                .padding(.leading, 48 * scalingFactor)
                        }
                    }
                }
                .background(CMColor.surface)
                .cornerRadius(16 * scalingFactor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16 * scalingFactor)
                        .stroke(CMColor.secondaryText.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: CMColor.black.opacity(0.02), radius: 8 * scalingFactor, x: 0, y: 2 * scalingFactor)
            }
        }
    }
    
    private func fileRow(file: SafeStorageFile, scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                
                Image(systemName: file.icon)
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            // File name
            Text(file.name)
                .font(.system(size: 14 * scalingFactor))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
    }
}



// MARK: - Data Models
struct SafeStorageCategory: Identifiable {
    let id = UUID()
    let title: String
    let count: String
    let icon: String
    let color: Color
}

struct SafeStorageFile: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}
