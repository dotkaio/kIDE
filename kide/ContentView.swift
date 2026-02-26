import SwiftUI
import UniformTypeIdentifiers

struct TreeRow: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let depth: Int

    var id: URL { url }
}

struct ContentView: View {
    @State private var isPickingFolder = false

    @State private var workspace = WorkspaceStore()
    @State private var documents = DocumentStore()

    enum FocusTarget: Hashable {
        case sidebar
        case editor
    }

    @FocusState private var focus: FocusTarget?

    var body: some View {
        NavigationSplitView {
            List(selection: $workspace.selection) {
                if let rootFolder = workspace.rootFolder {
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
            .focused($focus, equals: .sidebar)
            .onAppear { focus = .sidebar }
            .onMoveCommand { direction in
                guard let selected = workspace.selection else { return }
                switch direction {
                case .right:
                    workspace.expandIfDirectory(selected)
                case .left:
                    workspace.collapseIfExpanded(selected)
                default:
                    break
                }
            }
            .onChange(of: workspace.selection) { _, selected in
                guard let selected else { return }

                if workspace.isDirectory(selected) {
                    focus = .sidebar
                } else {
                    documents.openFile(selected)
                    focus = .editor
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
                    workspace.openWorkspace(folder)
                    documents.clear()
                case .failure(let error):
                    print("Folder pick failed: \(error)")
                }
            }
        } detail: {
            if let activeDoc = documents.activeDoc {
                VStack(spacing: 0) {
                    HStack {
                        Text(activeDoc.url.lastPathComponent)
                            .font(.headline)

                        Text(activeDoc.isDirty ? "●" : "")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(activeDoc.text.utf8.count) bytes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    TextEditor(text: Binding(
                        get: { documents.activeDoc?.text ?? "" },
                        set: { documents.updateActiveText($0) }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .ideInputModifiers()
                    .focused($focus, equals: .editor)
                    .padding(8)
                }
            } else {
                Text("Select a file")
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kideSave)) { _ in
            documents.saveActiveFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kideTogglePaneFocus)) { _ in
            switch focus {
            case .sidebar:
                focus = .editor
            default:
                focus = .sidebar
            }
        }
        .onDisappear {
            workspace.closeWorkspace()
            documents.clear()
        }
        #endif
    }

    // MARK: - Tree rows

    private var rows: [TreeRow] {
        guard let rootFolder = workspace.rootFolder else { return [] }
        return buildRows(in: rootFolder, depth: 0)
    }

    private func buildRows(in folder: URL, depth: Int) -> [TreeRow] {
        let children = workspace.children(of: folder)
        var out: [TreeRow] = []

        for child in children {
            out.append(TreeRow(url: child.url, isDirectory: child.isDirectory, depth: depth))
            if child.isDirectory, workspace.expanded.contains(child.url) {
                out += buildRows(in: child.url, depth: depth + 1)
            }
        }

        return out
    }

    private func rowView(_ row: TreeRow) -> some View {
        HStack(spacing: 6) {
            if row.isDirectory {
                Button {
                    workspace.toggleExpanded(row.url)
                } label: {
                    Image(systemName: workspace.expanded.contains(row.url) ? "chevron.down" : "chevron.right")
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
        .onTapGesture {
            workspace.selection = row.url
        }
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
