//
//  BackupSettingsManager.swift
//  cleanme2
//
//  Created by AI Assistant on 03.09.25.
//

import Foundation
import Combine
import os.log

/// Manages backup-related settings and preferences
final class BackupSettingsManager: ObservableObject {
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "BackupSettings")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Settings Keys
    private enum SettingsKeys {
        static let isAutoBackupEnabled = "isAutoBackupEnabled_v1"
        static let lastBackupDate = "lastBackupDate_v1"
        static let totalBackupsCount = "totalBackupsCount_v1"
    }
    
    // MARK: - Published Properties
    
    /// Indicates whether auto backup is enabled
    @Published var isAutoBackupEnabled: Bool {
        didSet {
            userDefaults.set(isAutoBackupEnabled, forKey: SettingsKeys.isAutoBackupEnabled)
            logger.info("🔄 Auto backup setting changed to: \(self.isAutoBackupEnabled)")
        }
    }
    
    /// Last backup date for display purposes
    @Published var lastBackupDate: Date? {
        didSet {
            if let date = lastBackupDate {
                userDefaults.set(date, forKey: SettingsKeys.lastBackupDate)
                logger.info("📅 Last backup date updated: \(date.formatted())")
            }
        }
    }
    
    /// Total number of backups created
    @Published var totalBackupsCount: Int {
        didSet {
            userDefaults.set(totalBackupsCount, forKey: SettingsKeys.totalBackupsCount)
            logger.info("📊 Total backups count updated: \(self.totalBackupsCount)")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Human readable last backup date
    var lastBackupDisplayText: String {
        guard let date = lastBackupDate else {
            return "Never"
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today at \(DateFormatter.timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(DateFormatter.timeFormatter.string(from: date))"
        } else {
            return DateFormatter.backupDateFormatter.string(from: date)
        }
    }
    
    // MARK: - Singleton
    static let shared = BackupSettingsManager()
    
    private init() {
        // Load settings from UserDefaults
        self.isAutoBackupEnabled = userDefaults.bool(forKey: SettingsKeys.isAutoBackupEnabled)
        self.lastBackupDate = userDefaults.object(forKey: SettingsKeys.lastBackupDate) as? Date
        self.totalBackupsCount = userDefaults.integer(forKey: SettingsKeys.totalBackupsCount)
        
        logger.info("🏗️ BackupSettingsManager initialized")
        logger.info("   📱 Auto backup enabled: \(self.isAutoBackupEnabled)")
        logger.info("   📅 Last backup: \(self.lastBackupDate?.formatted() ?? "None")")
        logger.info("   📊 Total backups: \(self.totalBackupsCount)")
    }
    
    // MARK: - Public Methods
    
    /// Increments backup count and updates last backup date
    func recordSuccessfulBackup() {
        totalBackupsCount += 1
        lastBackupDate = Date()
        logger.info("✅ Backup recorded successfully")
    }
    
    /// Resets all backup settings
    func resetSettings() {
        isAutoBackupEnabled = false
        lastBackupDate = nil
        totalBackupsCount = 0
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: SettingsKeys.isAutoBackupEnabled)
        userDefaults.removeObject(forKey: SettingsKeys.lastBackupDate)
        userDefaults.removeObject(forKey: SettingsKeys.totalBackupsCount)
        
        logger.info("🧹 Backup settings reset")
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
