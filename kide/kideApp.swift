import SwiftUI

extension Notification.Name {
    static let kideSave = Notification.Name("kide.save")
    static let kideTogglePaneFocus = Notification.Name("kide.togglePaneFocus")
    static let kideSaveAs = Notification.Name("kide.saveAs")
}

@main
struct kideApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .kideSave, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Save As…") {
                    NotificationCenter.default.post(name: .kideSaveAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar/Editor Focus") {
                    NotificationCenter.default.post(name: .kideTogglePaneFocus, object: nil)
                }
                .keyboardShortcut("\\", modifiers: [.command, .shift])
            }
        }
    }
}
