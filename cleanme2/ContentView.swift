import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingShown") var onboardingShown: Bool = false
      
      var body: some View {
          if onboardingShown {
              MediaCleanerView()
          } else {
              OnboardingView()
          }
          // Remove .preferredColorScheme(.light) to allow automatic theme switching
      }
}

#Preview {
    ContentView()
}
