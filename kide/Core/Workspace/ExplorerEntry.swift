import Foundation

struct ExplorerEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool

    var id: URL { url }
}
