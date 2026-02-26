import SwiftUI

@Observable
final class WorkspaceStore {
    var rootFolder: URL?
    var selection: URL?

    var expanded: Set<URL> = []
    private(set) var childrenCache: [URL: [ExplorerEntry]] = [:]

    // Security-scoped access (mainly relevant on iOS; safe on macOS).
    private var scopedRoot: URL?
    private var isScopeActive = false

    func openWorkspace(_ folder: URL) {
        stopScopeIfNeeded()

        scopedRoot = folder
        isScopeActive = folder.startAccessingSecurityScopedResource()

        rootFolder = folder
        selection = nil
        expanded.removeAll()
        childrenCache.removeAll()
    }

    func toggleExpanded(_ url: URL) {
        guard isDirectory(url) else { return }
        if expanded.contains(url) {
            expanded.remove(url)
        } else {
            expanded.insert(url)
        }
    }

    func expandIfDirectory(_ url: URL) {
        guard isDirectory(url) else { return }
        expanded.insert(url)
    }

    func collapseIfExpanded(_ url: URL) {
        expanded.remove(url)
    }

    func children(of folder: URL) -> [ExplorerEntry] {
        if let cached = childrenCache[folder] {
            return cached
        }

        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let mapped: [ExplorerEntry] = urls.map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return ExplorerEntry(url: url, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
        }

        childrenCache[folder] = mapped
        return mapped
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    func closeWorkspace() {
        stopScopeIfNeeded()
        rootFolder = nil
        selection = nil
        expanded.removeAll()
        childrenCache.removeAll()
    }

    private func stopScopeIfNeeded() {
        if isScopeActive, let scopedRoot {
            scopedRoot.stopAccessingSecurityScopedResource()
        }
        isScopeActive = false
        scopedRoot = nil
    }

    deinit {
        stopScopeIfNeeded()
    }
}
