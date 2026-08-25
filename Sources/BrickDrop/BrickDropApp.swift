import SwiftUI

@main
struct BrickDropApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("SD Card") {
                Button("Choose SD Card…") { model.chooseSDCard() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Clean Metadata Now") { model.cleanMetadataNow() }
                    .disabled(model.sdRoot == nil || model.isWorking)
                Divider()
                Button("Eject SD Card") { model.ejectSDCard() }
                    .disabled(!model.canEject)
            }
        }
    }
}
