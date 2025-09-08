//
//  WordDocumentPreviewView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import QuickLook
import Foundation

struct WordDocumentPreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Navigation bar
                    navigationBar(safeAreaTop: geometry.safeAreaInsets.top)
                    
                    // Document content
                    documentContentView
                }
            }
        }
        .navigationBarHidden(true)
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
    
    // MARK: - Navigation Bar
    private func navigationBar(safeAreaTop: CGFloat) -> some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            // Document title
            Text(document.fileName)
                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16 * scalingFactor) {
                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                // Delete button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.error)
                }
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, safeAreaTop + 8 * scalingFactor)
        .padding(.bottom, 12 * scalingFactor)
        .background(
            CMColor.background
                .shadow(color: CMColor.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    // MARK: - Document Content View
    private var documentContentView: some View {
        VStack(spacing: 0) {
            // Document info header
            documentInfoHeader
            
            // Document content
            documentTextContentView
        }
    }
    
    // MARK: - Document Info Header
    private var documentInfoHeader: some View {
        VStack(spacing: 16 * scalingFactor) {
            // Document card
            HStack(spacing: 12 * scalingFactor) {
                // Document icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20 * scalingFactor))
                        .foregroundColor(CMColor.primary)
                }
                
                VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                    Text(document.fileName)
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                        .lineLimit(1)
                    
                    Text("\(document.fileSizeFormatted) • \(document.fileExtension?.uppercased() ?? "DOC")")
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
            }
            .padding(.all, 16 * scalingFactor)
            .background(CMColor.surface)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(CMColor.border.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 16 * scalingFactor)
    }
    
    // MARK: - Document Text Content View
    private var documentTextContentView: some View {
        VStack(spacing: 0) {
            // QuickLook preview
            if QLPreviewController.canPreview(document.documentURL as QLPreviewItem) {
                WordDocumentQuickLookView(url: document.documentURL)
                    .background(CMColor.white)
                    .cornerRadius(0)
                    .padding(.horizontal, 16 * scalingFactor)
            } else {
                // Fallback content
                fallbackContentView
            }
        }
    }
    
    // MARK: - Fallback Content View
    private var fallbackContentView: some View {
        VStack(spacing: 20 * scalingFactor) {
            Spacer()
            
            VStack(spacing: 16 * scalingFactor) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.primary.opacity(0.6))
                
                VStack(spacing: 8 * scalingFactor) {
                    Text("Preview Not Available")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("This document format cannot be previewed directly. You can share it to open in another app.")
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scalingFactor)
                }
                
                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                        
                        Text("Open in Another App")
                            .font(.system(size: 16 * scalingFactor, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 48 * scalingFactor)
                    .frame(maxWidth: 240 * scalingFactor)
                    .background(CMColor.primary)
                    .cornerRadius(24 * scalingFactor)
                }
                .padding(.top, 8 * scalingFactor)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16 * scalingFactor)
    }
    
    // MARK: - Helper Methods
    private func deleteDocument() {
        isDeleting = true
        safeStorageManager.deleteDocuments([document])
        dismiss()
    }
}

// MARK: - Word Document QuickLook View
struct WordDocumentQuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        
        // Customize appearance for embedded view
        controller.navigationItem.setHidesBackButton(true, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.refreshCurrentPreviewItem()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var parent: WordDocumentQuickLookView
        
        init(_ parent: WordDocumentQuickLookView) {
            self.parent = parent
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
        
        // Hide the navigation bar and toolbar for embedded view
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            // This won't be called in embedded mode, but good to have
        }
    }
}

// MARK: - Preview
#Preview {
    WordDocumentPreviewView(
        document: SafeDocumentData(
            documentURL: URL(fileURLWithPath: "/tmp/sample.doc"),
            fileName: "Example Document.doc",
            fileSize: 1024000,
            fileExtension: "doc"
        )
    )
    .environmentObject(SafeStorageManager())
}
