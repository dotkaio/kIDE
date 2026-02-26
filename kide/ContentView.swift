import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let kideSave = Notification.Name("kide.save")
}

struct ExplorerEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var id: URL { url }
}

struct TreeRow: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let depth: Int
    var id: URL { url }
}

struct ContentView: View {
    @State private var isPickingFolder = false

    @State private var rootFolder: URL?
    @State private var selection: URL?

    @State private var expanded: Set<URL> = []
    @State private var childrenCache: [URL: [ExplorerEntry]] = [:]

    @State private var openedFile: URL?
    @State private var editorText: String = ""

    @State private var isDirty: Bool = false
    @State private var lastSavedText: String = ""

    // For sandboxed access (important on iOS; harmless on macOS).
    @State private var scopedRoot: URL?
    @State private var isScopeActive = false

    @FocusState private var sidebarFocused: Bool

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if let rootFolder {
                    Section(rootFolder.lastPathComponent) {
                        ForEach(rows, id: \.self) { row in
                            rowView(row)
                                .tag(row.url as URL?)
                        }
                    }
                } else {
                    Text("Open a folder to start")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Explorer")
            .focused($sidebarFocused)
            .onAppear { sidebarFocused = true }
            .onMoveCommand { direction in
                guard let sel = selection else { return }
                switch direction {
                case .right:
                    expandIfDirectory(sel)
                case .left:
                    collapseIfExpanded(sel)
                default:
                    break
                }
            }
            .onChange(of: selection) { _, newValue in
                openIfFile(newValue)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isPickingFolder = true
                    } label: {
                        Label("Open Folder", systemImage: "folder")
                    }
                }
            }
            .fileImporter(
                isPresented: $isPickingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let folder = urls.first else { return }
                    setRootFolder(folder)
                case .failure(let error):
                    print("Folder pick failed: \(error)")
                }
            }
        } detail: {
            if let openedFile {
                VStack(spacing: 0) {
                    HStack {
                        Text(openedFile.lastPathComponent)
                            .font(.headline)

                        Text(isDirty ? "●" : "")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(editorText.utf8.count) bytes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    TextEditor(text: $editorText)
                        .font(.system(.body, design: .monospaced))
                        .ideInputModifiers()
                        .padding(8)
                        .onChange(of: editorText) { _, newValue in
                            isDirty = (newValue != lastSavedText)
                        }
                }
            } else {
                Text("Select a file")
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kideSave)) { _ in
            saveActiveFile()
        }
        .onDisappear {
            stopScopeIfNeeded()
        }
    }

    // MARK: - Tree rows

    private var rows: [TreeRow] {
        guard let rootFolder else { return [] }
        return buildRows(in: rootFolder, depth: 0)
    }

    private func buildRows(in folder: URL, depth: Int) -> [TreeRow] {
        let children = children(of: folder)
        var out: [TreeRow] = []

        for child in children {
            out.append(TreeRow(url: child.url, isDirectory: child.isDirectory, depth: depth))
            if child.isDirectory, expanded.contains(child.url) {
                out += buildRows(in: child.url, depth: depth + 1)
            }
        }
        return out
    }

    private func rowView(_ row: TreeRow) -> some View {
        HStack(spacing: 6) {
            if row.isDirectory {
                Button {
                    toggleExpanded(row.url)
                } label: {
                    Image(systemName: expanded.contains(row.url) ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 14)
            }

            Image(systemName: row.isDirectory ? "folder" : "doc.text")
                .foregroundStyle(.secondary)

            Text(row.url.lastPathComponent)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, CGFloat(row.depth) * 14)
        .contentShape(Rectangle())
    }

    // MARK: - Expand/collapse + open

    private func toggleExpanded(_ url: URL) {
        guard isDirectory(url) else { return }
        if expanded.contains(url) { expanded.remove(url) }
        else { expanded.insert(url) }
    }

    private func expandIfDirectory(_ url: URL) {
        guard isDirectory(url) else { return }
        if !expanded.contains(url) { expanded.insert(url) }
    }

    private func collapseIfExpanded(_ url: URL) {
        if expanded.contains(url) { expanded.remove(url) }
    }

    private func openIfFile(_ url: URL?) {
        guard let url else {
            openedFile = nil
            editorText = ""
            lastSavedText = ""
            isDirty = false
            return
        }
        if isDirectory(url) {
            openedFile = nil
            editorText = ""
            lastSavedText = ""
            isDirty = false
        } else {
            openedFile = url
            let loaded = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            editorText = loaded
            lastSavedText = loaded
            isDirty = false
        }
    }

    // MARK: - Save

    private func saveActiveFile() {
        guard let url = openedFile else { return }
        do {
            try editorText.write(to: url, atomically: true, encoding: .utf8)
            lastSavedText = editorText
            isDirty = false
        } catch {
            print("Save failed: \(error)")
        }
    }

    // MARK: - Filesystem helpers

    private func children(of folder: URL) -> [ExplorerEntry] {
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
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
        }

        return mapped
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    // MARK: - Root folder + security scope

    private func setRootFolder(_ folder: URL) {
        stopScopeIfNeeded()

        scopedRoot = folder
        isScopeActive = folder.startAccessingSecurityScopedResource()

        rootFolder = folder
        selection = nil
        expanded.removeAll()
        childrenCache.removeAll()

        openedFile = nil
        editorText = ""
        lastSavedText = ""
        isDirty = false
    }

    private func stopScopeIfNeeded() {
        if isScopeActive, let scopedRoot {
            scopedRoot.stopAccessingSecurityScopedResource()
        }
        isScopeActive = false
        scopedRoot = nil
    }
}

private extension View {
    @ViewBuilder
    func ideInputModifiers() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
        #else
        self
        #endif
    }
}

#Preview {
    ContentView()
}
