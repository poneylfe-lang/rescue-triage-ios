import SwiftUI

@main
struct RescueTriageApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            QueueView().environmentObject(store)
        }
    }
}
