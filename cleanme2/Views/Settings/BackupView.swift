//
//  BackupView.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import CloudKit

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupSettings = BackupSettingsManager.shared
    @StateObject private var iCloudService = iCloudBackupService()
    @State private var isBackingUp: Bool = false
    @State private var showBackupAlert: Bool = false
    @State private var backupMessage: String = ""
    @State private var showShareSheet: Bool = false
    @State private var backupFileURL: URL?
    @State private var selectedBackup: BackupItem?
    @State private var showBackupDetail: Bool = false
    @State private var showICloudBackupDetail: Bool = false
    @State private var selectedICloudBackup: iCloudBackupItem?
    @State private var realBackups: [BackupItem] = []
    
    // For testing: change to [] to see no backups state
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    navigationBar
                    
                    ScrollView {
                        VStack(spacing: 32 * scalingFactor) {
                            // Auto backup section
                            autoBackupSection
                            
                            // Existing backups section or cloud illustration
                            if !realBackups.isEmpty {
                                existingBackupsSection
                            } else {
                                // Cloud illustration and content (only when no backups)
                                cloudIllustrationSection
                            }
                            
                            Spacer(minLength: 100 * scalingFactor)
                        }
                        .padding(.horizontal, 20 * scalingFactor)
                        .padding(.top, 24 * scalingFactor)
                    }
                    
                    // Bottom backup button
                    backupButton
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await iCloudService.fetchBackupHistory()
            }
        }
        .alert("Backup Contacts", isPresented: $showBackupAlert) {
            if backupFileURL != nil {
                Button("Share") {
                    showShareSheet = true
                    backupMessage = ""
                }
                Button("OK") {
                    backupMessage = ""
                }
            } else {
                Button("OK") {
                    backupMessage = ""
                }
            }
        } message: {
            Text(backupMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = backupFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $showBackupDetail) {
            BackupDetailView(backup: selectedBackup ?? BackupItem(date: Date(), contactsCount: 0, size: "0 MB"))
        }
        .onChange(of: showBackupDetail) { newValue in
            if !newValue {
                realBackups = BackupHistoryManager.shared.loadBackups()
                
                Task {
                    await iCloudService.fetchBackupHistory()
                }
            }
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            Text("Backup")
                .font(.system(size: 20 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            // Invisible spacer for balance
            HStack(spacing: 6 * scalingFactor) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17 * scalingFactor, weight: .medium))
                Text("Back")
                    .font(.system(size: 17 * scalingFactor, weight: .regular))
            }
            .opacity(0)
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 16 * scalingFactor)
    }
    
    // MARK: - Auto Backup Section
    private var autoBackupSection: some View {
        VStack(spacing: 16 * scalingFactor) {
            HStack {
                VStack(alignment: .leading, spacing: 8 * scalingFactor) {
                    Text("Auto backup")
                        .font(.system(size: 20 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("The app automatically backs up contacts to iCloud before merging or deleting them.")
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Toggle("", isOn: $backupSettings.isAutoBackupEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: CMColor.primary))
                    .scaleEffect(0.9)
            }
            
            // Auto backup status info
            if backupSettings.isAutoBackupEnabled {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(CMColor.primary)
                        .font(.system(size: 14 * scalingFactor))
                    
                    VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                        Text("iCloud backup enabled")
                            .font(.system(size: 13 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text("Last backup: \(backupSettings.lastBackupDisplayText)")
                            .font(.system(size: 12 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    Spacer()
                    
                    Text("\(backupSettings.totalBackupsCount) backups")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                .padding(.horizontal, 4 * scalingFactor)
                .padding(.vertical, 8 * scalingFactor)
                .background(CMColor.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8 * scalingFactor))
            }
        }
        .padding(.horizontal, 4 * scalingFactor)
    }
    
    // MARK: - Existing Backups Section
    private var existingBackupsSection: some View {
        VStack(alignment: .leading, spacing: 20 * scalingFactor) {
            HStack {
                Text("Existing backups")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                Text("\(realBackups.count)")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
                    .padding(.horizontal, 8 * scalingFactor)
                    .padding(.vertical, 4 * scalingFactor)
                    .background(CMColor.primary.opacity(0.1))
                    .cornerRadius(8 * scalingFactor)
            }
            .padding(.horizontal, 4 * scalingFactor)
            
            VStack(spacing: 12 * scalingFactor) {
                ForEach(realBackups) { backup in
                    BackupRowView(
                        backup: backup, 
                        scalingFactor: scalingFactor,
                        onTap: {
                            selectedBackup = backup
                            showBackupDetail = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Cloud Illustration Section
    private var cloudIllustrationSection: some View {
        VStack(spacing: 32 * scalingFactor) {
            // Cloud illustration
            cloudIllustration
            
            // Content section
            VStack(spacing: 24 * scalingFactor) {
                VStack(spacing: 16 * scalingFactor) {
                    Text("Contacts Backup")
                        .font(.system(size: 24 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("Make a backup of your contacts before working with them to avoid any unpleasant situations in the future.")
                        .font(.system(size: 16 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                
                Text("You will be able to recover the data after the application is reinstalled.")
                    .font(.system(size: 16 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
    }
    
    // MARK: - Cloud Illustration
    private var cloudIllustration: some View {
        ZStack {
            // Cloud shape with upload arrow
            VStack(spacing: 0) {
                // Cloud background
                ZStack {
                    // Main cloud shape
                    RoundedRectangle(cornerRadius: 40 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.15))
                        .frame(width: 120 * scalingFactor, height: 80 * scalingFactor)
                    
                    // Cloud bumps
                    HStack(spacing: -10 * scalingFactor) {
                        Circle()
                            .fill(CMColor.primary.opacity(0.15))
                            .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                            .offset(y: -15 * scalingFactor)
                        
                        Circle()
                            .fill(CMColor.primary.opacity(0.15))
                            .frame(width: 60 * scalingFactor, height: 60 * scalingFactor)
                            .offset(y: -20 * scalingFactor)
                        
                        Circle()
                            .fill(CMColor.primary.opacity(0.15))
                            .frame(width: 45 * scalingFactor, height: 45 * scalingFactor)
                            .offset(y: -12 * scalingFactor)
                    }
                    
                    // Upload arrow
                    VStack(spacing: 4 * scalingFactor) {
                        // Arrow head
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16 * scalingFactor, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Arrow shaft
                        Rectangle()
                            .fill(.white)
                            .frame(width: 3 * scalingFactor, height: 20 * scalingFactor)
                            .cornerRadius(1.5 * scalingFactor)
                    }
                    .offset(y: 2 * scalingFactor)
                }
            }
        }
        .frame(height: 120 * scalingFactor)
    }
    
    // MARK: - Backup Button
    private var backupButton: some View {
        VStack(spacing: 12 * scalingFactor) {
            // iCloud backup button
            Button(action: {
                performICloudBackup()
            }) {
                HStack {
                    if isBackingUp || iCloudService.isBackingUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text("Backing up to iCloud...")
                            .font(.system(size: 17 * scalingFactor, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Back Up to iCloud")
                            .font(.system(size: 17 * scalingFactor, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56 * scalingFactor)
                .background(
                    RoundedRectangle(cornerRadius: 16 * scalingFactor)
                        .fill((isBackingUp || iCloudService.isBackingUp) ? CMColor.primary.opacity(0.7) : CMColor.primary)
                )
            }
            .disabled(isBackingUp || iCloudService.isBackingUp)
            
            // Local backup button (secondary)
            Button(action: {
                performLocalBackup()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Export Local Backup")
                        .font(.system(size: 15 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44 * scalingFactor)
                .background(
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .stroke(CMColor.primary, lineWidth: 1)
                )
            }
            .disabled(isBackingUp || iCloudService.isBackingUp)
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.bottom, 34 * scalingFactor)
        .animation(.easeInOut(duration: 0.2), value: isBackingUp)
        .animation(.easeInOut(duration: 0.2), value: iCloudService.isBackingUp)
        .background(CMColor.background)
        .onAppear {
            realBackups = BackupHistoryManager.shared.loadBackups()
            
            Task {
                await iCloudService.fetchBackupHistory()
            }
        }
    }
    
    // MARK: - Backup Functions
    
    /// Performs iCloud backup
    private func performICloudBackup() {
        let contactsManager = ContactsPersistenceManager.shared
        let contacts = contactsManager.loadContacts()
        
        guard !contacts.isEmpty else {
            backupMessage = "No contacts found to backup."
            showBackupAlert = true
            return
        }
        
        // 1. Кодируем контакты, чтобы получить размер данных
        var backupSizeString: String = "0 MB"
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(contacts)
            
            // 2. Получаем размер в байтах и форматируем
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useAll]
            byteCountFormatter.countStyle = .file
            backupSizeString = byteCountFormatter.string(fromByteCount: Int64(encodedData.count))
            
        } catch {
            print("❌ Failed to encode contacts to determine size: \(error.localizedDescription)")
        }
        
        Task {
            let success = await iCloudService.backupContacts(contacts)
            
            await MainActor.run {
                if success {
                    let newBackupItem = BackupItem(date: Date(), contactsCount: contacts.count, size: backupSizeString)
                    realBackups.insert(newBackupItem, at: 0)
                    BackupHistoryManager.shared.saveBackups(realBackups)
                    backupMessage = "Successfully backed up \(contacts.count) contacts to iCloud! ☁️"
                } else {
                    let errorMessage = iCloudService.lastError?.localizedDescription ?? "Unknown error"
                    backupMessage = "Failed to backup contacts to iCloud: \(errorMessage)"
                }
                showBackupAlert = true
            }
        }
    }
    
    /// Performs local backup (original functionality)
    private func performLocalBackup() {
        guard !isBackingUp else { return }
        
        isBackingUp = true
        
        Task {
            do {
                let contactsManager = ContactsPersistenceManager.shared
                let contacts = contactsManager.loadContacts()
                
                guard !contacts.isEmpty else {
                    await MainActor.run {
                        isBackingUp = false
                        backupMessage = "No contacts found to backup."
                        showBackupAlert = true
                    }
                    return
                }
                
                // Simulate backup process
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Create backup data with pretty formatting
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                let backupData = try encoder.encode(contacts)
                
                // Get documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = dateFormatter.string(from: Date())
                let backupURL = documentsPath.appendingPathComponent("contacts_backup_\(dateString).json")
                
                // Save backup file
                try backupData.write(to: backupURL)
                
                await MainActor.run {
                    isBackingUp = false
                    backupFileURL = backupURL
                    backupMessage = "Successfully backed up \(contacts.count) contacts!\n\nWould you like to share the backup file?"
                    showBackupAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    backupMessage = "Failed to backup contacts: \(error.localizedDescription)"
                    showBackupAlert = true
                }
            }
        }
    }
}

// MARK: - Backup Row View
struct BackupRowView: View {
    let backup: BackupItem
    let scalingFactor: CGFloat
    let onTap: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            // Backup icon
            ZStack {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 44 * scalingFactor, height: 44 * scalingFactor)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 20 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            // Backup info
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                HStack {
                    Text(backup.dayOfWeek)
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                    
                    Spacer()
                    
                    Text(backup.dateString)
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                HStack {
                    Text("\(backup.contactsCount) contacts")
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                    
                    Spacer()
                    
                    Text(backup.size)
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            // Arrow icon
            Image(systemName: "chevron.right")
                .font(.system(size: 14 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 14 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(12 * scalingFactor)
        .shadow(color: CMColor.border.opacity(0.1), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - ShareSheet UIViewControllerRepresentable
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview
#Preview {
    BackupView()
}
