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
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.16, blue: 0.24), Color(red: 0.11, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().overlay(.white.opacity(0.08))

                HStack(spacing: 0) {
                    sidebar
                    Divider().overlay(.white.opacity(0.08))
                    editorArea
                }
            }
            .background(Color(red: 0.10, green: 0.11, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .padding(24)
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
    }

    // MARK: - Shell UI

    private var topBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.33)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.23)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.19, green: 0.81, blue: 0.35)).frame(width: 12, height: 12)
            }

            Label(workspace.rootFolder?.lastPathComponent ?? "kIDE", systemImage: "curlybraces")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            if let activeDoc = documents.activeDoc {
                Text(activeDoc.url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("No File Selected")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red.opacity(0.9))
                Text("4").foregroundStyle(.white.opacity(0.7))
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow.opacity(0.9))
                Text("12").foregroundStyle(.white.opacity(0.7))
            }
            .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ForEach(["folder", "globe", "magnifyingglass", "shippingbox", "play", "ladybug", "exclamationmark.triangle", "square.grid.2x2"], id: \.self) { icon in
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.02))

            Divider().overlay(.white.opacity(0.08))

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
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
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

            HStack {
                Button {
                    isPickingFolder = true
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
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
        }
        .frame(width: 330)
        .background(Color(red: 0.12, green: 0.13, blue: 0.19))
    }

    private var editorArea: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(.white.opacity(0.08))

            if let _ = documents.activeDoc {
                HStack(spacing: 0) {
                    codeEditor
                    Divider().overlay(.white.opacity(0.08))
                    miniMap
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.25))
                    Text("Select a file from Explorer")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(red: 0.10, green: 0.11, blue: 0.15))
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(documents.openDocs) { doc in
                    Button {
                        documents.activeDocID = doc.id
                        focus = .editor
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                            Text(doc.url.lastPathComponent)
                            if doc.isDirty {
                                Circle()
                                    .fill(.white.opacity(0.75))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white.opacity(doc.id == documents.activeDocID ? 0.95 : 0.6))
                        .background(doc.id == documents.activeDocID ? Color.blue.opacity(0.22) : .clear)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20).overlay(.white.opacity(0.08))
                }
            }
            .padding(.leading, 6)
        }
        .frame(height: 44)
        .background(Color.black.opacity(0.24))
    }

    private var codeEditor: some View {
        TextEditor(text: Binding(
            get: { documents.activeDoc?.text ?? "" },
            set: { documents.updateActiveText($0) }
        ))
        .font(.system(size: 16, weight: .regular, design: .monospaced))
        .foregroundStyle(.white.opacity(0.92))
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.11, green: 0.12, blue: 0.17))
        .ideInputModifiers()
        .focused($focus, equals: .editor)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var miniMap: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<26, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 2)
                    .fill(idx % 5 == 0 ? Color.blue.opacity(0.65) : Color.white.opacity(0.22))
                    .frame(width: miniMapLineWidth(for: idx), height: 3)
            }
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 10)
        .frame(width: 90)
        .background(Color.black.opacity(0.18))
    }

    private func miniMapLineWidth(for idx: Int) -> CGFloat {
        let widths: [CGFloat] = [30, 42, 26, 48, 54, 34, 50, 28]
        return widths[idx % widths.count]
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
