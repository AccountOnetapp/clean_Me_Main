//
//  PhotosView.swift
//  cleanme2
//
//  Created by AI Assistant on 13.08.25.
//

import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct PhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @State private var searchText: String = ""
    @State private var isSelectionMode: Bool = false
    @State private var selectedPhotos: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool
    
    // Photo picker state
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var showImagePicker = false
    @State private var isLoadingImages = false
    
    // Delete confirmation
    @State private var showDeleteConfirmation = false
    
    private var photos: [SafePhotoData] {
        safeStorageManager.loadAllPhotos()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844 // Standard iPhone scaling
            
            VStack(spacing: 0) {
                // Header
                headerView(scalingFactor: scalingFactor)
                
                if photos.isEmpty {
                    // Empty state
                    emptyStateView(scalingFactor: scalingFactor)
                } else {
                    // Photos content
                    photosContentView(scalingFactor: scalingFactor)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: selectedPickerItems) { items in
            loadImages(from: items)
        }
        .confirmationDialog("Delete Photos", isPresented: $showDeleteConfirmation) {
            Button("Delete \(selectedPhotos.count) Photos", role: .destructive) {
                deleteSelectedPhotos()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(selectedPhotos.count) selected photos? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Media")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Photos")
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !photos.isEmpty {
                Button(action: {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedPhotos.removeAll()
                    }
                }) {
                    HStack(spacing: 4 * scalingFactor) {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 6 * scalingFactor, height: 6 * scalingFactor)
                        Text("Select")
                            .font(.system(size: 16 * scalingFactor))
                            .foregroundColor(CMColor.primary)
                    }
                }
            } else {
                Spacer().frame(width: 60 * scalingFactor)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
    }
    
    // MARK: - Empty State
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            // Empty state icon
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scalingFactor, height: 120 * scalingFactor)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No photos yet")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first photo to get started")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Add photo button
            PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 10, matching: .images) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Add photo")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scalingFactor)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scalingFactor)
            }
            .padding(.horizontal, 40 * scalingFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Photos Content
    private func photosContentView(scalingFactor: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24 * scalingFactor) {
                // Search bar
                searchBar(scalingFactor: scalingFactor)
                
                // Content section with conditional display
                if !isSearchFocused || !searchText.isEmpty {
                    // Photos sections
                    photosSectionsView(scalingFactor: scalingFactor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Add image button
                    addImageButton(scalingFactor: scalingFactor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Dynamic bottom spacing based on search state
                Spacer(minLength: isSearchFocused ? 200 * scalingFactor : 100 * scalingFactor)
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.top, 20 * scalingFactor)
            .animation(.easeInOut(duration: 0.3), value: isSearchFocused)
        }
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
                        // Handle search submission and dismiss keyboard
                        isSearchFocused = false
                    }
                
                Spacer()
                
                if isSearchFocused && !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
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
            .background(CMColor.cardBackground)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(isSearchFocused ? CMColor.primary.opacity(0.3) : CMColor.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    // MARK: - Photos Sections
    private func photosSectionsView(scalingFactor: CGFloat) -> some View {
        let groupedPhotos = Dictionary(grouping: photos) { photo in
            formatDate(photo.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 16 * scalingFactor) {
            ForEach(groupedPhotos.keys.sorted(by: { first, second in
                if first == "Today" { return true }
                if second == "Today" { return false }
                return first < second
            }), id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 12 * scalingFactor) {
                    // Date header
                    Text(dateKey)
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    // Photos grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * scalingFactor), count: 3), spacing: 8 * scalingFactor) {
                        ForEach(groupedPhotos[dateKey] ?? []) { photo in
                            photoThumbnail(photo: photo, scalingFactor: scalingFactor)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo Thumbnail
    private func photoThumbnail(photo: SafePhotoData, scalingFactor: CGFloat) -> some View {
        NavigationLink(destination: PhotoDetailView(photo: photo)) {
            ZStack {
                // Photo
                if let uiImage = photo.fullImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: (UIScreen.main.bounds.width - 48 * scalingFactor) / 3, height: (UIScreen.main.bounds.width - 48 * scalingFactor) / 3)
                        .clipped()
                        .cornerRadius(12 * scalingFactor)
                } else {
                    // Placeholder for missing image
                    Rectangle()
                        .fill(CMColor.secondaryText.opacity(0.3))
                        .frame(width: (UIScreen.main.bounds.width - 48 * scalingFactor) / 3, height: (UIScreen.main.bounds.width - 48 * scalingFactor) / 3)
                        .cornerRadius(12 * scalingFactor)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                        )
                }
            
                // Selection overlay
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                if selectedPhotos.contains(photo.id) {
                                    selectedPhotos.remove(photo.id)
                                } else {
                                    selectedPhotos.insert(photo.id)
                                }
                            }) {
                                Image(systemName: selectedPhotos.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20 * scalingFactor))
                                    .foregroundColor(selectedPhotos.contains(photo.id) ? .white : .white.opacity(0.7))
                                    .background(
                                        Circle()
                                            .fill(selectedPhotos.contains(photo.id) ? CMColor.primary : Color.black.opacity(0.3))
                                            .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                                    )
                            }
                            .padding(8 * scalingFactor)
                        }
                        Spacer()
                    }
                }
            }
        }
        .disabled(isSelectionMode) // Disable navigation when in selection mode
    }
    
    // MARK: - Add Image Button
    private func addImageButton(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 12 * scalingFactor) {
            if isLoadingImages {
                // Loading state
                HStack(spacing: 8 * scalingFactor) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Adding images...")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scalingFactor)
                .background(CMColor.primary.opacity(0.7))
                .cornerRadius(16 * scalingFactor)
            } else {
                PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 10, matching: .images) {
                    Text("Add image")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52 * scalingFactor)
                        .background(CMColor.primary)
                        .cornerRadius(16 * scalingFactor)
                }
                .disabled(isLoadingImages)
            }
            
            // Delete selected photos button (only show in selection mode)
            if isSelectionMode && !selectedPhotos.isEmpty {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "trash")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                        
                        Text("Delete Selected (\(selectedPhotos.count))")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scalingFactor)
                    .background(Color.red)
                    .cornerRadius(16 * scalingFactor)
                }
                .disabled(isLoadingImages)
            }
        }
        .padding(.top, 20 * scalingFactor)
        .animation(.easeInOut(duration: 0.2), value: isLoadingImages)
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        isLoadingImages = true
        
        Task {
            defer {
                DispatchQueue.main.async {
                    self.isLoadingImages = false
                    self.selectedPickerItems.removeAll()
                }
            }
            
            // Process images with progress feedback
            for (index, item) in items.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // Save each image and wait for completion
                    let savedPhoto = await self.safeStorageManager.savePhotoAsync(imageData: data)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        if savedPhoto != nil {
                            print("Successfully saved image \(index + 1)/\(items.count)")
                        } else {
                            print("Failed to save image \(index + 1)/\(items.count)")
                        }
                        // Force UI refresh by triggering objectWillChange
                        self.safeStorageManager.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    private func deleteSelectedPhotos() {
        let photosToDelete = photos.filter { photo in
            selectedPhotos.contains(photo.id)
        }
        
        safeStorageManager.deletePhotos(photosToDelete)
        selectedPhotos.removeAll()
        isSelectionMode = false
    }
}

// MARK: - iOS 15 Compatible Version
struct PhotosViewLegacy: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @State private var searchText: String = ""
    @State private var isSelectionMode: Bool = false
    @State private var selectedPhotos: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool
    @State private var showImagePicker = false
    
    private var photos: [SafePhotoData] {
        safeStorageManager.loadAllPhotos()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            VStack(spacing: 0) {
                // Header (same as iOS 16+ version)
                headerView(scalingFactor: scalingFactor)
                
                if photos.isEmpty {
                    emptyStateView(scalingFactor: scalingFactor)
                } else {
                    photosContentView(scalingFactor: scalingFactor)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
    }
    
    // Similar implementation methods as iOS 16+ version but without PhotosPicker
    private func headerView(scalingFactor: CGFloat) -> some View {
        // Same implementation as iOS 16+ version
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Media")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Photos")
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !photos.isEmpty {
                Button(action: {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedPhotos.removeAll()
                    }
                }) {
                    HStack(spacing: 4 * scalingFactor) {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 6 * scalingFactor, height: 6 * scalingFactor)
                        Text("Select")
                            .font(.system(size: 16 * scalingFactor))
                            .foregroundColor(CMColor.primary)
                    }
                }
            } else {
                Spacer().frame(width: 60 * scalingFactor)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
    }
    
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            // Empty state icon
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scalingFactor, height: 120 * scalingFactor)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No photos yet")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first photo to get started")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Add photo button (using legacy approach)
            Button(action: {
                showImagePicker = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Add photo")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scalingFactor)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scalingFactor)
            }
            .padding(.horizontal, 40 * scalingFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func photosContentView(scalingFactor: CGFloat) -> some View {
        // Simplified content view for iOS 15
        Text("Photos view for iOS 15")
            .font(.system(size: 16 * scalingFactor))
            .foregroundColor(CMColor.primaryText)
    }
}

// MARK: - Version Compatible Wrapper
struct MainPhotosView: View {
    var body: some View {
        NavigationView {
            if #available(iOS 16.0, *) {
                PhotosView()
            } else {
                PhotosViewLegacy()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Ensure proper navigation on iPad
    }
}

// MARK: - Preview
#Preview {
    MainPhotosView()
        .environmentObject(SafeStorageManager())
}