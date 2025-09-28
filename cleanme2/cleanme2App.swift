import SwiftUI
import AppsFlyerLib
import AdSupport
import ApphudSDK
import AppTrackingTransparency

@main
struct cleanme2App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var safeStorageManager = SafeStorageManager()
    
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
        //        AppsFlyerLib.shared().customerUserID = uniqueUserID
        AppsFlyerLib.shared().appleAppID = "id6751836390"
        AppsFlyerLib.shared().appsFlyerDevKey = "wtHLXJZ3Zoc82BcxrHmDdK"
        AppsFlyerLib.shared().delegate = AppsFlyerDelegateHandler.shared
        
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
                        ATTrackingManager.requestTrackingAuthorization { status in
                            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                            let finalIdfa = idfa == "00000000-0000-0000-0000-000000000000" ? nil : idfa

                            Apphud.setDeviceIdentifiers(idfa: finalIdfa, idfv: nil)
                            AppsFlyerLib.shared().start()

                            print("ATT Status: \(status.rawValue)")
                            print("IDFA after request: \(idfa)")
                            
                            let defaults = UserDefaults.standard
                            let hasLaunchedKey = "hasLaunchedBefore"
                            
                            if !defaults.bool(forKey: hasLaunchedKey) {
                                // Это первый запуск
                                AppsFlyerLib.shared().logEvent("af_first_open", withValues: nil)
                                defaults.set(true, forKey: hasLaunchedKey)
                                print("First launch event sent")
                            }
                            
                            // Всегда фиксируем обычный запуск
                            AppsFlyerLib.shared().logEvent("af_app_launch", withValues: nil)
                        }
                    }
                }
        }
    }
}

// MARK: - AppsFlyer Delegate Wrapper
class AppsFlyerDelegateHandler: NSObject, AppsFlyerLibDelegate {
    static let shared = AppsFlyerDelegateHandler()
    var conversionData: [AnyHashable: Any]?

    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        conversionData = data
        print("onConversionDataSuccess data:")
        for (key, value) in data {
            print(key, ":", value)
        }
        
        Apphud.setAttribution(
            data: ApphudAttributionData(rawData: data),
            from: .appsFlyer,
            identifer: AppsFlyerLib.shared().getAppsFlyerUID()
        ) { _ in }
    }

    func onConversionDataFail(_ error: Error) {
        print("[AFSDK] \(error.localizedDescription)")
        Apphud.setAttribution(
            data: ApphudAttributionData(rawData: ["error": error.localizedDescription]),
            from: .appsFlyer,
            identifer: AppsFlyerLib.shared().getAppsFlyerUID()
        ) { _ in }
    }
}
