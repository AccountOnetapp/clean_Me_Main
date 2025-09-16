import SwiftUI
import AppsFlyerLib
import AdSupport
import ApphudSDK
import AppTrackingTransparency // 1. Импортируем фреймворк ATT

@main
struct cleanme2App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var safeStorageManager = SafeStorageManager()
    
    // Инициализация Apphud и AppsFlyer
    init() {
        // --- Логика для AppsFlyer CUID ---
        let defaults = UserDefaults.standard
        let customerUserIDKey = "customer_user_id"
        var uniqueUserID: String
        if let storedUserID = defaults.string(forKey: customerUserIDKey) {
            uniqueUserID = storedUserID
        } else {
            uniqueUserID = UUID().uuidString
            defaults.set(uniqueUserID, forKey: customerUserIDKey)
        }
        AppsFlyerLib.shared().customerUserID = uniqueUserID
        AppsFlyerLib.shared().appleAppID = "id6751836390"
        AppsFlyerLib.shared().appsFlyerDevKey = "wtHLXJZ3Zoc82BcxrHmDdK"
        AppsFlyerLib.shared().isDebug = true
        // --- Конец логики для AppsFlyer CUID ---
        
        // --- Логика для Apphud ---
        Apphud.start(apiKey: "app_jEb3hDLqfYmxG9hpwnJBFZUxn4hTeM")
        print("Apphud initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(safeStorageManager)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        // 2. Запрашиваем ATT разрешение
                        ATTrackingManager.requestTrackingAuthorization { status in
                            // 3. Код, который выполнится после того, как пользователь сделает выбор
                            // Запускаем AppsFlyer и отправляем IDFA
                            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                            let finalIdfa = idfa == "00000000-0000-0000-0000-000000000000" ? nil : idfa
                            
                            // Apphud и AppsFlyer получают IDFA после разрешения
                            Apphud.setDeviceIdentifiers(idfa: finalIdfa, idfv: nil)
                            AppsFlyerLib.shared().start()
                            
                            print("ATT Status: \(status.rawValue)")
                            print("IDFA after request: \(idfa)")
                        }
                    }
                }
        }
    }
}
