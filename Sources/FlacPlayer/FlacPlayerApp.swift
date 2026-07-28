import FlacPlayerCore
import SwiftData
import SwiftUI

@main
struct FlacPlayerApp: App {
    let container: ModelContainer
    @State private var playerModel = PlayerModel()

    init() {
        do {
            container = try FlacPlayerSchema.makeContainer()
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerModel)
        }
        .modelContainer(container)
    }
}
