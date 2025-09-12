//
//  CalendarInstructionsView.swift
//  cleanme2
//
//  Created by AI Assistant on 18.08.25.
//

import SwiftUI

struct CalendarInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingOtherSolutions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("How to unsubscribe from a spam calendar?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    
                    // Calendar Screenshot
                    calendarScreenshotView()
                        .padding(.horizontal, 20)
                    
                    // Instructions
                    instructionsView()
                        .padding(.horizontal, 20)
                    
                    // Action Buttons
                    actionButtonsView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(CMColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(CMColor.primary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Instructions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
            }
        }
        .sheet(isPresented: $showingOtherSolutions) {
            OtherSolutionsView()
        }
    }
    
    // MARK: - Calendar Screenshot View
    
    private func calendarScreenshotView() -> some View {
        VStack(spacing: 0) {
            // Mock calendar interface
            RoundedRectangle(cornerRadius: 16)
                .fill(CMColor.surface)
                .overlay {
                    VStack(spacing: 0) {
                        // Calendar events mockup
                        calendarEventsView()
                        
                        // Bottom tab bar mockup
                        HStack {
                            calendarTabItem("Today", isSelected: true)
                            Spacer()
                            calendarTabItem("Calendars", isSelected: false)
                            Spacer()
                            calendarTabItem("Inbox", isSelected: false)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(CMColor.backgroundSecondary)
                    }
                }
                .frame(height: 500)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private func calendarEventsView() -> some View {
        VStack(spacing: 0) {
            // Time slots with events
            VStack(spacing: 8) {
                // 9 AM
                timeSlotView(time: "9 AM", events: [
                    CalendarEventModel(title: "***Special gift just 🎁 you***", color: .pink, isSpam: true)
                ])
                
                timeSlotView(time: "9:41 AM", events: [
                    CalendarEventModel(title: "Marketing team meeting", color: .yellow, isSpam: false)
                ])
                
                // 10 AM
                timeSlotView(time: "10 AM", events: [
                    CalendarEventModel(title: "***Special gift just 🎁 you***", color: .pink, isSpam: true)
                ])
                
                // 11 AM
                timeSlotView(time: "11 AM", events: [
                    CalendarEventModel(title: "Team scavenger hunt (virtual)", color: .yellow, isSpam: false),
                    CalendarEventModel(title: "Hurry Up & Get Money Back 😃", color: .pink, isSpam: true)
                ])
                
                // Noon
                timeSlotView(time: "Noon", events: [
                    CalendarEventModel(title: "Lunch with Erny", color: .blue, isSpam: false),
                    CalendarEventModel(title: "Hurry Up & Get Money Back 😃", color: .pink, isSpam: true)
                ])
                
                // 1 PM
                timeSlotView(time: "1 PM", events: [
                    CalendarEventModel(title: "🛍️ Discounted deals now 🛍️", color: .pink, isSpam: true)
                ])
                
                // 2 PM
                timeSlotView(time: "2 PM", events: [
                    CalendarEventModel(title: "***Special gift just 🎁 you***", color: .pink, isSpam: true)
                ])
                
                // 3 PM
                timeSlotView(time: "3 PM", events: [
                    CalendarEventModel(title: "Video brainstorming session", color: .yellow, isSpam: false),
                    CalendarEventModel(title: "Hurry Up & Get Money Back 😃", color: .pink, isSpam: true)
                ])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    private func timeSlotView(time: String, events: [CalendarEventModel]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            Text(time)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
                .frame(width: 50, alignment: .trailing)
            
            // Events
            VStack(spacing: 4) {
                ForEach(events.indices, id: \.self) { index in
                    let event = events[index]
                    HStack {
                        Rectangle()
                            .fill(event.color)
                            .frame(width: 3)
                        
                        Text(event.title)
                            .font(.system(size: 13, weight: event.isSpam ? .medium : .regular))
                            .foregroundColor(event.isSpam ? .primary : CMColor.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(event.isSpam ? Color.pink.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func calendarTabItem(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(isSelected ? CMColor.primary : CMColor.secondaryText)
    }
    
    // MARK: - Instructions View
    
    private func instructionsView() -> some View {
        VStack(spacing: 20) {
            // Step instruction
            HStack(spacing: 16) {
                // Arrow icon
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap on the Spam event or Calendars")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("Unsubscribe from the calendar")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(CMColor.surface)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Action Buttons View
    
    private func actionButtonsView() -> some View {
        VStack(spacing: 16) {
            // Go to calendar button
            Button(action: {
                openCalendarApp()
            }) {
                Text("Go to calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.primary)
                    .cornerRadius(12)
            }
            
            // Other solutions button
            Button(action: {
                showOtherSolutions()
            }) {
                Text("Other solutions")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(CMColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
            }
        }
    }
    
    // MARK: - Actions
    
    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "x-apple-calevent://") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
    
    private func showOtherSolutions() {
        showingOtherSolutions = true
    }
}

// MARK: - Preview

#Preview {
    CalendarInstructionsView()
}
