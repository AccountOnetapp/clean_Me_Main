import SwiftUI
import AdSupport
import ApphudSDK

@main
struct cleanme2App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var safeStorageManager = SafeStorageManager()
    
    init() {
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        Apphud.start(apiKey: "app_jEb3hDLqfYmxG9hpwnJBFZUxn4hTeM")
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: idfa)
        
        print("Apphud initialized with IDFA: \(idfa)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(safeStorageManager)
        }
    }
}
