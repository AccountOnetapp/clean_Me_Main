//
//  PasswordCodeView.swift
//  cleanme2
//
//  Created by AI Assistant on 12.08.25.
//

import SwiftUI
import LocalAuthentication
import UIKit

struct PasswordCodeView: View {
    @State private var enteredCode: String = ""
    @State private var pinSetupState: PinSetupState = .entry
    @State private var storedPin: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var biometricType: LABiometryType = .none
    @State private var isBiometricAvailable: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - New State for Change Passcode Flow
    // Добавляем новое состояние для отслеживания шагов в процессе смены пароля
    @State private var changePasscodeState: ChangePasscodeFlowState = .verifyingOldPin
    
    let requiredLength: Int = 4
    let onTabBarVisibilityChange: (Bool) -> Void
    let onCodeEntered: (String) -> Void
    let onBackButtonTapped: () -> Void
    let shouldAutoDismiss: Bool
    
    // MARK: - New Property
    // Новый параметр, чтобы указать, что мы в процессе смены пароля
    let isChangingPasscode: Bool
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    enum PinSetupState {
        case setup
        case entry
        case confirm
    }
    
    // MARK: - New Enum
    // Новый перечислитель для управления потоком смены пароля
    enum ChangePasscodeFlowState {
        case verifyingOldPin
        case settingNewPin
        case confirmingNewPin
    }
    
    init(
        onTabBarVisibilityChange: @escaping (Bool) -> Void = { _ in },
        onCodeEntered: @escaping (String) -> Void = { _ in },
        onBackButtonTapped: @escaping () -> Void = { },
        shouldAutoDismiss: Bool = true,
        isChangingPasscode: Bool = false // Устанавливаем значение по умолчанию
    ) {
        self.onTabBarVisibilityChange = onTabBarVisibilityChange
        self.onCodeEntered = onCodeEntered
        self.onBackButtonTapped = onBackButtonTapped
        self.shouldAutoDismiss = shouldAutoDismiss
        self.isChangingPasscode = isChangingPasscode
    }
    
    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                Spacer()
                
                pinCodeSection
                
                Spacer()
                
                keypadSection
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 34 * scalingFactor)
            }
        }
        .onAppear {
            checkPinStatus()
            onTabBarVisibilityChange(false)
        }
        .onDisappear {
            onTabBarVisibilityChange(true)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: {
                onBackButtonTapped()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(CMColor.primary)
                }
                .padding(.vertical, 8 * scalingFactor)
                .padding(.horizontal, 4 * scalingFactor)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            Spacer()
            
            Text(titleText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {}) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                }
            }
            .opacity(0)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
    }
    
    // MARK: - PIN Code Section
    private var pinCodeSection: some View {
        VStack(spacing: 32 * scalingFactor) {
            VStack(spacing: 16 * scalingFactor) {
                Text("PIN code")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(CMColor.primaryText)
                
                Text(descriptionText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
            
            HStack(spacing: 20 * scalingFactor) {
                ForEach(0..<requiredLength, id: \.self) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 12 * scalingFactor, height: 12 * scalingFactor)
                        .scaleEffect(index < enteredCode.count ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: enteredCode.count)
                        .animation(.easeInOut(duration: 0.2), value: showError)
                }
            }
            
            if showError {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16 * scalingFactor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Keypad Section
    private var keypadSection: some View {
        VStack(spacing: 16 * scalingFactor) {
            HStack(spacing: 60 * scalingFactor) {
                ForEach(1...3, id: \.self) { number in
                    KeypadButton(
                        text: "\(number)",
                        action: { addDigit("\(number)") }
                    )
                }
            }
            
            HStack(spacing: 60 * scalingFactor) {
                ForEach(4...6, id: \.self) { number in
                    KeypadButton(
                        text: "\(number)",
                        action: { addDigit("\(number)") }
                    )
                }
            }
            
            HStack(spacing: 60 * scalingFactor) {
                ForEach(7...9, id: \.self) { number in
                    KeypadButton(
                        text: "\(number)",
                        action: { addDigit("\(number)") }
                    )
                }
            }
            
            HStack(spacing: 60 * scalingFactor) {
                Button(action: {
                    authenticateWithBiometrics()
                }) {
                    Image(systemName: biometricIconName)
                        .font(.system(size: 24 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primaryText)
                        .frame(width: 60 * scalingFactor, height: 60 * scalingFactor)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(shouldShowBiometricButton ? 1.0 : 0.0)
                
                KeypadButton(
                    text: "0",
                    action: { addDigit("0") }
                )
                
                Button(action: deleteDigit) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 24 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primaryText)
                        .frame(width: 60 * scalingFactor, height: 60 * scalingFactor)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(enteredCode.isEmpty ? 0.3 : 1.0)
                .disabled(enteredCode.isEmpty)
            }
        }
        .padding(.bottom, 64 * scalingFactor)
    }
    
    // MARK: - Helper Properties
    private var titleText: String {
        if isChangingPasscode {
            return "Change Password"
        } else if pinSetupState == .setup || pinSetupState == .confirm {
            return "Create Password"
        } else {
            return "Safe storage"
        }
    }
    
    private var descriptionText: String {
        if isChangingPasscode {
            switch changePasscodeState {
            case .verifyingOldPin:
                return "Enter your current PIN"
            case .settingNewPin:
                return "Enter your new PIN"
            case .confirmingNewPin:
                return "Confirm your new PIN"
            }
        } else {
            switch pinSetupState {
            case .setup:
                return "Create a 4-digit PIN to secure your safe storage"
            case .entry:
                return ""
            case .confirm:
                return "Confirm your PIN"
            }
        }
    }
    
    private var shouldShowBiometricButton: Bool {
        // Показываем кнопку биометрии только если:
        // 1. Биометрия доступна на устройстве
        // 2. PIN уже установлен (не в режиме настройки или подтверждения)
        // 3. Не в процессе смены пароля (в этом случае нужно только ввести PIN)
        return isBiometricAvailable && 
               pinSetupState == .entry && 
               !isChangingPasscode
    }
    
    private var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "faceid" // Fallback к FaceID иконке
        }
    }
    
    // MARK: - Helper Methods
    private func dotColor(for index: Int) -> Color {
        if showError {
            return .red
        } else if index < enteredCode.count {
            return CMColor.primaryText
        } else {
            return CMColor.secondaryText.opacity(0.3)
        }
    }
    
    private func clearError() {
        if showError {
            withAnimation(.easeInOut(duration: 0.3)) {
                showError = false
                errorMessage = ""
            }
        }
    }
    
    private func showErrorState(message: String) {
        errorMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            clearError()
        }
    }
    
    private func addDigit(_ digit: String) {
        guard enteredCode.count < requiredLength else { return }
        
        clearError()
        enteredCode += digit
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if enteredCode.count == requiredLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                handleCompleteCode()
            }
        }
    }
    
    private func handleCompleteCode() {
        if isChangingPasscode {
            handlePasscodeChangeFlow()
        } else {
            handlePinSetupFlow()
        }
    }
    
    private func handlePinSetupFlow() {
        switch pinSetupState {
        case .setup:
            storedPin = enteredCode
            pinSetupState = .confirm
            enteredCode = ""
            
        case .confirm:
            if enteredCode == storedPin {
                UserDefaults.standard.set(enteredCode, forKey: "safe_storage_pin")
                onCodeEntered(enteredCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                showErrorState(message: "PINs don't match. Please try again.")
                enteredCode = ""
                storedPin = ""
                pinSetupState = .setup
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .entry:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if enteredCode == savedPin {
                onCodeEntered(enteredCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                showErrorState(message: "Incorrect PIN. Please try again.")
                enteredCode = ""
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func handlePasscodeChangeFlow() {
        switch changePasscodeState {
        case .verifyingOldPin:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if enteredCode == savedPin {
                // Verified old PIN, move to setting new one
                enteredCode = ""
                withAnimation {
                    changePasscodeState = .settingNewPin
                }
            } else {
                // Incorrect old PIN
                showErrorState(message: "Incorrect PIN. Please try again.")
                enteredCode = ""
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .settingNewPin:
            // Store the new PIN and move to confirmation
            storedPin = enteredCode
            enteredCode = ""
            withAnimation {
                changePasscodeState = .confirmingNewPin
            }
            
        case .confirmingNewPin:
            // Confirm the new PIN
            if enteredCode == storedPin {
                // New PINs match, save it
                UserDefaults.standard.set(enteredCode, forKey: "safe_storage_pin")
                onCodeEntered(enteredCode) // Callback to inform parent
                
                // Dismiss the view on success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } else {
                // New PINs don't match, show error and restart setting new PIN
                showErrorState(message: "PINs don't match. Please try again.")
                enteredCode = ""
                storedPin = ""
                withAnimation {
                    changePasscodeState = .settingNewPin
                }
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func checkPinStatus() {
        if !isChangingPasscode {
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin")
            if savedPin == nil || savedPin?.isEmpty == true {
                pinSetupState = .setup
            } else {
                pinSetupState = .entry
            }
        }
        
        checkBiometricAvailability()
    }
    
    // MARK: - Biometric Authentication Methods
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    private func authenticateWithBiometrics() {
        guard isBiometricAvailable else { return }
        
        let context = LAContext()
        let reason = "Используйте биометрию для входа в безопасное хранилище"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Успешная биометрическая аутентификация
                    let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
                    self.onCodeEntered(savedPin)
                    
                    if self.shouldAutoDismiss {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.dismiss()
                        }
                    }
                } else if let error = error {
                    // Обработка ошибок биометрической аутентификации
                    self.handleBiometricError(error as NSError)
                }
            }
        }
    }
    
    private func handleBiometricError(_ error: NSError) {
        let message: String
        
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            message = "Биометрическая аутентификация недоступна"
        case LAError.biometryNotEnrolled.rawValue:
            message = "Биометрические данные не настроены"
        case LAError.biometryLockout.rawValue:
            message = "Биометрия заблокирована. Попробуйте позже"
        case LAError.userCancel.rawValue:
            // Пользователь отменил аутентификацию - не показываем ошибку
            return
        case LAError.userFallback.rawValue:
            // Пользователь выбрал ввод PIN - не показываем ошибку
            return
        default:
            message = "Ошибка биометрической аутентификации"
        }
        
        showErrorState(message: message)
    }
    
    private func deleteDigit() {
        guard !enteredCode.isEmpty else { return }
        
        clearError()
        
        enteredCode.removeLast()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Keypad Button
struct KeypadButton: View {
    let text: String
    let action: () -> Void
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 28 * scalingFactor, weight: .regular))
                .foregroundColor(CMColor.primaryText)
                .frame(width: 60 * scalingFactor, height: 60 * scalingFactor)
                .contentShape(Circle())
        }
        .buttonStyle(KeypadButtonStyle())
    }
}

// MARK: - Keypad Button Style
struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(configuration.isPressed ? CMColor.secondaryText.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
