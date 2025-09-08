//
//  EnhancedDocumentPreviewView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import QuickLook
import PDFKit
import WebKit
import Foundation

struct EnhancedDocumentPreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    
    @State private var documentContent: DocumentContent = .loading
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private enum DocumentContent {
        case loading
        case text(String)
        case pdf(PDFDocument)
        case image(UIImage)
        case web(String) // HTML content
        case unsupported
        case error(String)
    }
    
    var body: some View {
        // Route to specialized preview based on file type
        Group {
            if let fileExtension = document.fileExtension?.lowercased() {
                switch fileExtension {
                case "doc", "docx":
                    WordDocumentPreviewView(document: document)
                        .environmentObject(safeStorageManager)
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif":
                    ImageDocumentPreviewView(document: document)
                        .environmentObject(safeStorageManager)
                default:
                    // Fallback to original enhanced view for other types
                    originalEnhancedView
                }
            } else {
                // No extension - use original view
                originalEnhancedView
            }
        }
    }
    
    // MARK: - Original Enhanced View
    private var originalEnhancedView: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView(scalingFactor: scalingFactor)
                    
                    // Content
                    contentView(scalingFactor: scalingFactor)
                }
            }
        }
        .onAppear {
            loadDocumentContent()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [document.documentURL])
        }
        .alert("Delete Document", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteDocument()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(document.fileName)\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            // Document title
            Text(document.displayName)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Delete button
            Button(action: {
                showDeleteAlert = true
            }) {
                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: CMColor.error))
                } else {
                    Text("Delete")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.error)
                }
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(CMColor.border)
            , alignment: .bottom
        )
    }
    
    // MARK: - Content View
    @ViewBuilder
    private func contentView(scalingFactor: CGFloat) -> some View {
        switch documentContent {
        case .loading:
            loadingView(scalingFactor: scalingFactor)
            
        case .text(let content):
            documentTextView(content: content, scalingFactor: scalingFactor)
            
        case .pdf(let pdfDocument):
            pdfDocumentView(pdfDocument: pdfDocument, scalingFactor: scalingFactor)
            
        case .image(let image):
            documentImageView(image: image, scalingFactor: scalingFactor)
            
        case .web(let htmlContent):
            webDocumentView(htmlContent: htmlContent, scalingFactor: scalingFactor)
            
        case .unsupported:
            unsupportedView(scalingFactor: scalingFactor)
            
        case .error(let errorMessage):
            errorView(errorMessage: errorMessage, scalingFactor: scalingFactor)
        }
    }
    
    // MARK: - Loading View
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading document...")
                .font(.system(size: 16 * scalingFactor))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document Text View
    private func documentTextView(content: String, scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16 * scalingFactor) {
                // Document header info
                documentInfoCard(scalingFactor: scalingFactor)
                
                // Document content
                VStack(alignment: .leading, spacing: 12 * scalingFactor) {
                    Text("Document Content")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(content)
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.primaryText)
                        .lineSpacing(4 * scalingFactor)
                        .textSelection(.enabled)
                        .padding(16 * scalingFactor)
                        .background(CMColor.white)
                        .cornerRadius(12 * scalingFactor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                                .stroke(CMColor.border, lineWidth: 1)
                        )
                }
                
                // Action buttons
                actionButtonsView(scalingFactor: scalingFactor)
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    // MARK: - PDF Document View
    private func pdfDocumentView(pdfDocument: PDFDocument, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Document info bar
            documentInfoBar(scalingFactor: scalingFactor)
            
            // PDF content
            PDFViewRepresentable(document: pdfDocument)
                .background(CMColor.white)
        }
    }
    
    // MARK: - Document Image View
    private func documentImageView(image: UIImage, scalingFactor: CGFloat) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 16 * scalingFactor) {
                // Document header info
                documentInfoCard(scalingFactor: scalingFactor)
                    .padding(.horizontal, 16 * scalingFactor)
                
                // Image content
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(CMColor.white)
                    .cornerRadius(12 * scalingFactor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12 * scalingFactor)
                            .stroke(CMColor.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16 * scalingFactor)
                
                // Action buttons
                actionButtonsView(scalingFactor: scalingFactor)
                    .padding(.horizontal, 16 * scalingFactor)
            }
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    // MARK: - Web Document View
    private func webDocumentView(htmlContent: String, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Document info bar
            documentInfoBar(scalingFactor: scalingFactor)
            
            // Web content
            WebViewRepresentable(htmlContent: htmlContent)
                .background(CMColor.white)
        }
    }
    
    // MARK: - Unsupported View
    private func unsupportedView(scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                Spacer()
                
                // Document header info
                documentInfoCard(scalingFactor: scalingFactor)
                
                // Check if it's a .doc/.docx file that can use QuickLook
                if let fileExtension = document.fileExtension?.lowercased(),
                   ["doc", "docx"].contains(fileExtension) {
                    
                    // For Word documents, show QuickLook preview
                    VStack(spacing: 16 * scalingFactor) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48 * scalingFactor))
                            .foregroundColor(CMColor.primary)
                        
                        Text("Word Document")
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text("Text extraction unavailable, but you can view the document using the system preview.")
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32 * scalingFactor)
                        
                        // QuickLook preview if available
                        if QLPreviewController.canPreview(document.documentURL as QLPreviewItem) {
                            DocumentQuickLookView(url: document.documentURL)
                                .frame(height: 400 * scalingFactor)
                                .clipShape(RoundedRectangle(cornerRadius: 12 * scalingFactor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                                        .stroke(CMColor.border, lineWidth: 1)
                                )
                        }
                    }
                } else {
                    // For other unsupported types
                    VStack(spacing: 16 * scalingFactor) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text("Preview not available")
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text("This document type cannot be previewed, but you can still share or export it.")
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32 * scalingFactor)
                    }
                }
                
                // Action buttons
                actionButtonsView(scalingFactor: scalingFactor)
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    // MARK: - Error View
    private func errorView(errorMessage: String, scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                Spacer()
                
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.error)
                
                VStack(spacing: 8 * scalingFactor) {
                    Text("Cannot load document")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(errorMessage)
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scalingFactor)
                }
                
                // Document info
                documentInfoCard(scalingFactor: scalingFactor)
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    // MARK: - Document Info Card
    private func documentInfoCard(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scalingFactor) {
            HStack(spacing: 12 * scalingFactor) {
                // Document icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 48 * scalingFactor, height: 48 * scalingFactor)
                    
                    Image(systemName: document.iconName)
                        .font(.system(size: 24 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                // Document details
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text(document.fileName)
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                        .lineLimit(2)
                    
                    HStack(spacing: 8 * scalingFactor) {
                        Text(document.fileSizeFormatted)
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        if let fileExtension = document.fileExtension {
                            Text("•")
                                .font(.system(size: 14 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                            
                            Text(fileExtension.uppercased())
                                .font(.system(size: 14 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(16 * scalingFactor)
        .background(CMColor.cardBackground)
        .cornerRadius(12 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
    }
    
    // MARK: - Document Info Bar
    private func documentInfoBar(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            // Document icon
            ZStack {
                RoundedRectangle(cornerRadius: 6 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                
                Image(systemName: document.iconName)
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            // Document details
            VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                Text(document.fileName)
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 6 * scalingFactor) {
                    Text(document.fileSizeFormatted)
                        .font(.system(size: 12 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                    
                    if let fileExtension = document.fileExtension {
                        Text("•")
                            .font(.system(size: 12 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text(fileExtension.uppercased())
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            // Share button
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(CMColor.border)
            , alignment: .bottom
        )
    }
    
    // MARK: - Action Buttons
    private func actionButtonsView(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            // Share button
            Button(action: {
                showShareSheet = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Share")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48 * scalingFactor)
                .background(CMColor.primary)
                .cornerRadius(12 * scalingFactor)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadDocumentContent() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = document.documentURL
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: url.path) else {
                    DispatchQueue.main.async {
                        self.documentContent = .error("Document file not found")
                    }
                    return
                }
                
                // Determine content type based on file extension
                let fileExtension = document.fileExtension?.lowercased() ?? ""
                
                switch fileExtension {
                case "pdf":
                    if let pdfDocument = PDFDocument(url: url) {
                        DispatchQueue.main.async {
                            self.documentContent = .pdf(pdfDocument)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.documentContent = .error("Cannot load PDF document")
                        }
                    }
                    
                case "txt", "md", "rtf":
                    let content = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.documentContent = .text(content)
                    }
                    
                case "html", "htm":
                    let htmlContent = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.documentContent = .web(htmlContent)
                    }
                    
                case "doc", "docx":
                    // For Word documents, try to extract text content
                    self.loadWordDocument(from: url)
                    
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
                    if let image = UIImage(contentsOfFile: url.path) {
                        DispatchQueue.main.async {
                            self.documentContent = .image(image)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.documentContent = .error("Cannot load image")
                        }
                    }
                    
                default:
                    // Try to read as text first
                    if let content = try? String(contentsOf: url, encoding: .utf8),
                       !content.isEmpty,
                       content.count < 100000 { // Limit text size
                        DispatchQueue.main.async {
                            self.documentContent = .text(content)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.documentContent = .unsupported
                        }
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.documentContent = .error("Error loading document: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadWordDocument(from url: URL) {
        // For Word documents, check if file exists and use QuickLook preview
        if FileManager.default.fileExists(atPath: url.path) {
            DispatchQueue.main.async {
                self.documentContent = .unsupported
            }
        } else {
            DispatchQueue.main.async {
                self.documentContent = .error("Word document file not found")
            }
        }
    }
    
    private func deleteDocument() {
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Delete the document using SafeStorageManager
            self.safeStorageManager.deleteDocuments([self.document])
            
            DispatchQueue.main.async {
                self.isDeleting = false
                self.dismiss()
            }
        }
    }
}

// MARK: - PDF View Representable
struct PDFViewRepresentable: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update if needed
    }
}

// MARK: - Web View Representable
struct WebViewRepresentable: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update if needed
    }
}

// MARK: - Activity View is already defined in DocumentPreviewView.swift

// MARK: - Preview
#Preview {
    EnhancedDocumentPreviewView(
        document: SafeDocumentData(
            documentURL: URL(fileURLWithPath: "/tmp/sample.doc"),
            fileName: "Example_Document.doc",
            fileSize: 1024000,
            fileExtension: "doc"
        )
    )
    .environmentObject(SafeStorageManager())
}
