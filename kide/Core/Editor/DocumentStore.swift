import SwiftUI

struct Document: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var text: String
    var isDirty: Bool

    init(url: URL, text: String) {
        self.id = UUID()
        self.url = url
        self.text = text
        self.isDirty = false
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
            if let idx = openDocs.firstIndex(where: { $0.id == newValue.id }) {
                openDocs[idx] = newValue
            }
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
        doc.isDirty = true
        activeDoc = doc
    }
}
