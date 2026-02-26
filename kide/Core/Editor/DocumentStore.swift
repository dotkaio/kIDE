import SwiftUI

struct Document: Identifiable, Hashable {
    let id: UUID
    var url: URL
    var text: String
    var lastSavedText: String

    var isDirty: Bool {
        text != lastSavedText
    }

    init(url: URL, text: String) {
        self.id = UUID()
        self.url = url
        self.text = text
        self.lastSavedText = text
    }
}

@Observable
final class DocumentStore {
    var openDocs: [Document] = []
    var activeDocID: Document.ID?

    var activeDoc: Document? {
        get { openDocs.first(where: { $0.id == activeDocID }) }
        set {
            guard let newValue else { return }
            guard let idx = openDocs.firstIndex(where: { $0.id == newValue.id }) else { return }
            openDocs[idx] = newValue
        }
    }

    func openFile(_ url: URL) {
        if let existing = openDocs.first(where: { $0.url == url }) {
            activeDocID = existing.id
            return
        }

        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let doc = Document(url: url, text: text)
        openDocs.append(doc)
        activeDocID = doc.id
    }

    func updateActiveText(_ newText: String) {
        guard var doc = activeDoc else { return }
        doc.text = newText
        activeDoc = doc
    }

    func saveActiveFile() {
        guard var doc = activeDoc else { return }

        do {
            try doc.text.write(to: doc.url, atomically: true, encoding: .utf8)
            doc.lastSavedText = doc.text
            activeDoc = doc
        } catch {
            print("Save failed: \(error)")
        }
    }

    func clear() {
        openDocs.removeAll()
        activeDocID = nil
    }
}
