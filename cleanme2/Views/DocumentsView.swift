//
//  DocumentsView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @FocusState private var isSearchFocused: Bool
    @State private var isSelectionMode: Bool = false
    @State private var selectedDocuments: Set<UUID> = []
    
    // Document picker state
    @State private var showDocumentPicker = false
    @State private var isLoadingDocuments = false
    
    // Delete confirmation
    @State private var showDeleteConfirmation = false
    @State private var showDeleteFromDeviceAlert = false
    @State private var pendingDocuments: [DocumentPickerResult] = []
    
    // Document preview
    @State private var selectedDocumentForPreview: SafeDocumentData?
    @State private var showDocumentPreview = false
    
    private var documents: [SafeDocumentData] {
        let docs = safeStorageManager.loadAllDocuments()
        print("📊 Currently loaded documents: \(docs.count)")
        for (index, doc) in docs.enumerated() {
            print("📄 Document \(index + 1): \(doc.fileName) - \(doc.fileSizeFormatted)")
        }
        return docs
    }
    
    private var filteredDocuments: [SafeDocumentData] {
        if searchText.isEmpty {
            return documents
        } else {
            return documents.filter { document in
                document.fileName.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        mainContent
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: supportedFileTypes,
                allowsMultipleSelection: true
            ) { result in
                handleDocumentSelection(result)
            }
            .alert("Delete documents from device?", isPresented: $showDeleteFromDeviceAlert) {
                alertButtons
            } message: {
                alertMessage
            }
            .confirmationDialog("Delete Documents", isPresented: $showDeleteConfirmation) {
                confirmationButtons
            } message: {
                confirmationMessage
            }
            .fullScreenCover(isPresented: $showDocumentPreview) {
                documentPreviewContent
            }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844 // Standard iPhone scaling
            
            VStack(spacing: 0) {
                // Header
                headerView(scalingFactor: scalingFactor)
                
                if documents.isEmpty {
                    // Empty state
                    emptyStateView(scalingFactor: scalingFactor)
                } else {
                    // Documents content
                    documentsContentView(scalingFactor: scalingFactor)
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
    }
    
    // MARK: - Supporting Computed Properties
    private var supportedFileTypes: [UTType] {
        [
            .pdf, .plainText, .rtf,
            .commaSeparatedText, .tabSeparatedText,
            .zip, .data,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "xls") ?? .data,
            UTType(filenameExtension: "xlsx") ?? .data,
            UTType(filenameExtension: "ppt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data
        ]
    }
    
    private var alertButtons: some View {
        Group {
            Button("Yes") {
                Task {
                    await saveDocumentsAndDeleteFromDevice()
                }
            }
            Button("No", role: .cancel) {
                Task {
                    await saveDocumentsWithoutDeleting()
                }
            }
        }
    }
    
    private var alertMessage: some View {
        Text("Do you want to delete these documents from your device? Note: Documents from iCloud Drive and other cloud providers cannot be deleted, but will still be securely stored in this app.")
    }
    
    private var confirmationButtons: some View {
        Group {
            Button("Delete \(selectedDocuments.count) Documents", role: .destructive) {
                deleteSelectedDocuments()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var confirmationMessage: some View {
        Text("Are you sure you want to delete \(selectedDocuments.count) selected documents? This action cannot be undone.")
    }
    
    @ViewBuilder
    private var documentPreviewContent: some View {
        if let document = selectedDocumentForPreview {
            EnhancedDocumentPreviewView(document: document)
                .environmentObject(safeStorageManager)
                .onAppear {
                    print("🎬 Presenting EnhancedDocumentPreviewView for: \(document.fileName)")
                }
        } else {
            // Fallback view
            VStack {
                Text("Error")
                    .font(.title)
                Text("Document not found")
                    .foregroundColor(.secondary)
                Button("Close") {
                    showDocumentPreview = false
                }
                .padding()
            }
            .onAppear {
                print("❌ selectedDocumentForPreview is nil when trying to present preview")
            }
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
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Docs")
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !documents.isEmpty {
                Button(action: {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedDocuments.removeAll()
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
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No documents yet")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first document to get started")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Add document button
            Button(action: {
                showDocumentPicker = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Add document")
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
    
    // MARK: - Documents Content
    private func documentsContentView(scalingFactor: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24 * scalingFactor) {
                // Search bar
                searchBar(scalingFactor: scalingFactor)
                
                // Content section with conditional display
                if !isSearchFocused || !searchText.isEmpty {
                    // Documents sections
                    documentsSectionsView(scalingFactor: scalingFactor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Add document button
                    addDocumentButton(scalingFactor: scalingFactor)
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
            .background(CMColor.surface)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(isSearchFocused ? CMColor.primary.opacity(0.3) : CMColor.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    // MARK: - Documents Sections
    private func documentsSectionsView(scalingFactor: CGFloat) -> some View {
        let groupedDocuments = Dictionary(grouping: filteredDocuments) { document in
            formatDate(document.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 16 * scalingFactor) {
            ForEach(groupedDocuments.keys.sorted(by: { first, second in
                if first == "Today" { return true }
                if second == "Today" { return false }
                return first < second
            }), id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 12 * scalingFactor) {
                    // Date header
                    Text(dateKey)
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    // Documents list
                    VStack(spacing: 0) {
                        ForEach(Array((groupedDocuments[dateKey] ?? []).enumerated()), id: \.element.id) { index, document in
                            documentRow(document: document, scalingFactor: scalingFactor)
                            
                            if index < (groupedDocuments[dateKey]?.count ?? 0) - 1 {
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
    }
    
    // MARK: - Document Row
    private func documentRow(document: SafeDocumentData, scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            // Document icon or thumbnail
            documentIconView(document: document, scalingFactor: scalingFactor)
            
            // Document info
            VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                Text(document.displayName)
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                Text(document.fileSizeFormatted)
                    .font(.system(size: 12 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
            
            // Preview button (when not in selection mode)
            if !isSelectionMode {
                Button(action: {
                    selectedDocumentForPreview = document
                    showDocumentPreview = true
                }) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.primary)
                        .frame(width: 28 * scalingFactor, height: 28 * scalingFactor)
                        .background(CMColor.primary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Selection indicator
            if isSelectionMode {
                Button(action: {
                    if selectedDocuments.contains(document.id) {
                        selectedDocuments.remove(document.id)
                    } else {
                        selectedDocuments.insert(document.id)
                    }
                }) {
                    Image(systemName: selectedDocuments.contains(document.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20 * scalingFactor))
                        .foregroundColor(selectedDocuments.contains(document.id) ? CMColor.primary : CMColor.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                if selectedDocuments.contains(document.id) {
                    selectedDocuments.remove(document.id)
                } else {
                    selectedDocuments.insert(document.id)
                }
            } else {
                // Open document preview
                print("📱 User tapped on document: \(document.fileName)")
                print("📁 Document URL: \(document.documentURL.path)")
                print("📄 Document ID: \(document.id)")
                
                selectedDocuments.insert(document.id)
                selectedDocumentForPreview = document
                showDocumentPreview = true
                
                print("✅ Set selectedDocumentForPreview and showDocumentPreview = true")
            }
        }
    }
    
    // MARK: - Document Icon View
    private func documentIconView(document: SafeDocumentData, scalingFactor: CGFloat) -> some View {
        let isImageFile = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif"].contains(document.fileExtension?.lowercased() ?? "")
        
        return ZStack {
            RoundedRectangle(cornerRadius: 8 * scalingFactor)
                .fill(isImageFile ? Color.clear : CMColor.primary.opacity(0.1))
                .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
            
            if isImageFile {
                // Try to load and display image thumbnail
                ImageThumbnailView(documentURL: document.documentURL, scalingFactor: scalingFactor)
            } else {
                // Show regular document icon
                Image(systemName: document.iconName)
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
        }
    }
    
    // MARK: - Add Document Button
    private func addDocumentButton(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 12 * scalingFactor) {
            if isLoadingDocuments {
                // Loading state
                HStack(spacing: 8 * scalingFactor) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Adding documents...")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scalingFactor)
                .background(CMColor.primary.opacity(0.7))
                .cornerRadius(16 * scalingFactor)
            } else {
                Button(action: {
                    showDocumentPicker = true
                }) {
                    Text("Add document")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52 * scalingFactor)
                        .background(CMColor.primary)
                        .cornerRadius(16 * scalingFactor)
                }
                .disabled(isLoadingDocuments)
            }
            
            // Delete selected documents button (only show in selection mode)
            if isSelectionMode && !selectedDocuments.isEmpty {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "trash")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                        
                        Text("Delete Selected (\(selectedDocuments.count))")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scalingFactor)
                    .background(Color.red)
                    .cornerRadius(16 * scalingFactor)
                }
                .disabled(isLoadingDocuments)
            }
        }
        .padding(.top, 20 * scalingFactor)
        .animation(.easeInOut(duration: 0.2), value: isLoadingDocuments)
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
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            print("📄 Document picker selected \(urls.count) files")
            var documentResults: [DocumentPickerResult] = []
            
            for url in urls {
                print("🔍 Processing file: \(url.lastPathComponent)")
                print("📁 Original path: \(url.path)")
                print("🔧 URL scheme: \(url.scheme ?? "none")")
                print("🏠 Is file URL: \(url.isFileURL)")
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("❌ Failed to access security scoped resource for: \(url)")
                    continue
                }
                
                defer { 
                    url.stopAccessingSecurityScopedResource()
                    print("🔓 Released security scoped resource for: \(url.lastPathComponent)")
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    let fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension
                    
                    print("✅ Successfully read file: \(fileName), size: \(data.count) bytes")
                    
                    let documentResult = DocumentPickerResult(
                        data: data,
                        fileName: fileName,
                        fileExtension: fileExtension,
                        originalURL: url
                    )
                    
                    documentResults.append(documentResult)
                } catch {
                    print("❌ Error reading document data for \(url.lastPathComponent): \(error)")
                }
            }
            
            if !documentResults.isEmpty {
                print("📋 Prepared \(documentResults.count) documents for upload")
                pendingDocuments = documentResults
                showDeleteFromDeviceAlert = true
            } else {
                print("⚠️ No documents were successfully processed")
            }
            
        case .failure(let error):
            print("❌ Document picker error: \(error)")
        }
    }
    
    private func saveDocumentsAndDeleteFromDevice() async {
        isLoadingDocuments = true
        
        for documentResult in pendingDocuments {
            await saveDocument(documentResult)
            
            // Check if this is a file we can actually delete (e.g., local Downloads folder)
            // Document picker files are usually from iCloud Drive or other providers where deletion isn't allowed
            let url = documentResult.originalURL
            
            print("🗑️ Attempting to delete: \(documentResult.fileName)")
            print("📁 File path: \(url.path)")
            print("🏠 Is file URL: \(url.isFileURL)")
            print("🔧 URL scheme: \(url.scheme ?? "none")")
            
            // Always try to delete - let the system tell us if it's not allowed
            let isLocalFile = url.isFileURL && (
                url.path.contains("/Downloads/") || 
                url.path.contains("/tmp/") || 
                url.path.contains("/Documents/") ||
                url.path.contains("/Library/") ||
                url.path.contains("/var/")
            )
            
            print("📍 Is local file: \(isLocalFile)")
            
            // Always try to delete with security scoped access first
            do {
                // Ensure we have security scoped access for deletion
                let hasAccess = url.startAccessingSecurityScopedResource()
                print("🔐 Security scoped access granted: \(hasAccess)")
                
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                        print("🔓 Released security scoped access")
                    }
                }
                
                // Check if file still exists and we have write permissions
                let fileManager = FileManager.default
                let fileExists = fileManager.fileExists(atPath: url.path)
                let isDeletable = fileManager.isDeletableFile(atPath: url.path)
                
                print("📄 File exists: \(fileExists)")
                print("🗑️ File is deletable: \(isDeletable)")
                
                if fileExists && isDeletable {
                    try fileManager.removeItem(at: url)
                    print("✅ Successfully deleted document from device: \(documentResult.fileName)")
                } else if !fileExists {
                    print("ℹ️ Document no longer exists at: \(url.path)")
                } else {
                    print("⚠️ Document is not deletable at: \(url.path)")
                    print("🔍 Trying alternative deletion method...")
                    
                    // Try to delete using the Inbox approach for document picker files
                    if url.path.contains("/Inbox/") {
                        try fileManager.removeItem(at: url)
                        print("✅ Successfully deleted document from Inbox: \(documentResult.fileName)")
                    } else {
                        print("❌ Cannot delete document - it may be from iCloud Drive or another protected location")
                    }
                }
            } catch {
                print("❌ Could not delete document from device: \(error.localizedDescription)")
                print("📁 File path: \(url.path)")
                print("🔍 Error details: \(error)")
                
                // This is expected for most document picker files (iCloud Drive, etc.)
                if let nsError = error as NSError? {
                    print("🏷️ Error domain: \(nsError.domain)")
                    print("🔢 Error code: \(nsError.code)")
                }
            }
        }
        
        await MainActor.run {
            pendingDocuments.removeAll()
            isLoadingDocuments = false
            safeStorageManager.objectWillChange.send()
        }
    }
    
    private func saveDocumentsWithoutDeleting() async {
        isLoadingDocuments = true
        
        for documentResult in pendingDocuments {
            await saveDocument(documentResult)
        }
        
        await MainActor.run {
            pendingDocuments.removeAll()
            isLoadingDocuments = false
            safeStorageManager.objectWillChange.send()
        }
    }
    
    private func saveDocument(_ documentResult: DocumentPickerResult) async {
        let savedDocument = await safeStorageManager.saveDocumentAsync(
            documentData: documentResult.data,
            fileName: documentResult.fileName,
            fileExtension: documentResult.fileExtension
        )
        
        if savedDocument != nil {
            print("Successfully saved document: \(documentResult.fileName)")
        } else {
            print("Failed to save document: \(documentResult.fileName)")
        }
    }
    
    private func deleteSelectedDocuments() {
        let documentsToDelete = documents.filter { document in
            selectedDocuments.contains(document.id)
        }
        
        safeStorageManager.deleteDocuments(documentsToDelete)
        selectedDocuments.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Supporting Data Models
struct DocumentPickerResult {
    let data: Data
    let fileName: String
    let fileExtension: String?
    let originalURL: URL
}

// MARK: - Image Thumbnail View
struct ImageThumbnailView: View {
    let documentURL: URL
    let scalingFactor: CGFloat
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scalingFactor))
            } else {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 12 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            guard FileManager.default.fileExists(atPath: documentURL.path) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let imageData = try Data(contentsOf: documentURL)
                guard let fullImage = UIImage(data: imageData) else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // Create thumbnail
                let thumbnailSize = CGSize(width: 64 * scalingFactor, height: 64 * scalingFactor)
                let thumbnail = fullImage.preparingThumbnail(of: thumbnailSize)
                
                DispatchQueue.main.async {
                    self.thumbnailImage = thumbnail
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DocumentsView()
        .environmentObject(SafeStorageManager())
}
