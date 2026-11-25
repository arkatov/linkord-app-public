import AppKit
import SwiftUI

struct Draft: Identifiable {
    let id = UUID()
    var file: URL?
    var originalText: String?
    var folder: URL
    var address = ""
    var title = ""
    var notes = ""
    var manualTitle = false
    var manualNotes = false
    var added = Date()
    var pinned = false
}

@MainActor
final class Library: ObservableObject {
    @Published var root: URL?
    @Published var selected: URL? {
        didSet {
            if let selected, draft?.file == nil, draft?.folder != selected {
                draft?.folder = selected
            }
        }
    }
    @Published var catalog = Catalog()
    @Published var results: [LinkFile] = []
    @Published var query = "" { didSet { filter() } }
    private var metadataTask: Task<Void, Never>?
    @Published var draft: Draft? {
        didSet {
            if oldValue?.id != draft?.id || oldValue?.address != draft?.address {
                metadataTask?.cancel()
                guard let value = draft, value.file == nil || value.id == oldValue?.id,
                      let url = LinkFile.webURL(value.address) else { return }
                metadataTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled, let metadata = try? await PageMetadata.fetch(url),
                          !Task.isCancelled, var current = draft, current.id == value.id,
                          current.address == value.address else { return }
                    if !current.manualTitle, let title = metadata.title { current.title = title }
                    if !current.manualNotes, let notes = metadata.description { current.notes = notes }
                    guard current.title != draft?.title || current.notes != draft?.notes else { return }
                    draft = current
                    if current.file != nil { save(close: false) }
                }
            }
        }
    }
    @Published var error: String?
    @Published var loading = false
    @Published var newFolderParent: URL?
    @Published var expanded: Set<URL> = []
    private var watcher: FolderWatcher?
    private var revision = 0
    private var filterRevision = 0
    private var indexed: [(LinkFile, String)] = []
    private var refreshTask: Task<Void, Never>?
    var strings: L10n { L10n(language: UserDefaults.standard.string(forKey: "language") ?? "en") }

    init() {
        let path = UserDefaults.standard.string(forKey: "catalogPath") ?? ""
        if !path.isEmpty { open(URL(fileURLWithPath: path, isDirectory: true)) }
    }
    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = strings("choose")
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }
    func open(_ url: URL) {
        let url = url.resolvingSymlinksInPath().standardizedFileURL
        watcher = nil
        root = url; selected = url; expanded = [url]; draft = nil; query = ""
        catalog = Catalog(); indexed = []; results = []
        UserDefaults.standard.set(url.path, forKey: "catalogPath")
        watcher = FolderWatcher(root: url) { [weak self] in self?.refresh() }
        refresh()
    }
    func refresh() {
        guard let root else { return }
        revision += 1
        let token = revision
        loading = catalog.folders.isEmpty
        refreshTask?.cancel()
        refreshTask = Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try Catalog(root: root) } }.value
            guard token == revision, !Task.isCancelled else { return }
            loading = false
            switch result {
            case .success(let value):
                catalog = value
                indexed = value.links.map { ($0, $0.searchText) }
                if let selected, !value.folders.contains(selected) { self.selected = root }
                filter()
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }
    func select(_ folder: URL, toggle: Bool = false) {
        selected = folder
        if toggle {
            if expanded.contains(folder) { expanded.remove(folder) } else { expanded.insert(folder) }
        } else {
            var parent = folder
            while let root, parent.pathComponents.starts(with: root.pathComponents) {
                expanded.insert(parent)
                if parent == root { break }
                parent.deleteLastPathComponent()
            }
        }
        query = ""
    }
    func filter() {
        filterRevision += 1
        let token = filterRevision
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let indexed = indexed
        let folder = selected
        let sort = CardSort(rawValue: UserDefaults.standard.string(forKey: "cardSort") ?? "") ?? .created
        Task {
            let matches = await Task.detached(priority: .userInitiated) {
                indexed.compactMap { link, text in
                    (query.isEmpty ? folder.map { link.belongs(to: $0) } ?? true : text.contains(query)) ? link : nil
                }.sorted(by: sort.precedes)
            }.value
            if token == filterRevision { results = matches }
        }
    }
    func newLink() {
        guard let folder = selected ?? root else { choose(); return }
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        draft = Draft(folder: folder, address: LinkFile.webURL(clipboard)?.absoluteString ?? "")
    }
    func updateDraft(_ key: WritableKeyPath<Draft, String>, to text: String) {
        guard var value = draft, value[keyPath: key] != text else { return }
        if key == \.title { value.manualTitle = true }
        if key == \.notes { value.manualNotes = true }
        if key == \.address {
            if !value.manualTitle { value.title = "" }
            if !value.manualNotes { value.notes = "" }
        }
        value[keyPath: key] = text
        draft = value
        if value.file != nil { save(close: false) }
    }

    func loadMetadata(_ key: KeyPath<PageMetadata, String?>, into field: WritableKeyPath<Draft, String>) async {
        guard let original = draft, let url = LinkFile.webURL(original.address) else { return }
        let metadata = try? await PageMetadata.fetch(url)
        guard let current = draft, current.id == original.id, current.address == original.address,
              current[keyPath: field] == original[keyPath: field] else { return }
        guard let text = metadata?[keyPath: key] else {
            error = strings("metadataUnavailable")
            return
        }
        updateDraft(field, to: text)
    }

    func edit(_ link: LinkFile) {
        do {
            let text = try LinkFile.readText(from: link.id)
            guard let current = LinkFile(id: link.id, text: text) else { throw CocoaError(.fileReadCorruptFile) }
            draft = Draft(file: link.id, originalText: text, folder: link.id.deletingLastPathComponent(), address: current.url.absoluteString, title: current.title, notes: current.notes, manualTitle: !current.title.isEmpty, manualNotes: !current.notes.isEmpty, added: current.added, pinned: current.pinned)
        } catch { self.error = error.localizedDescription }
    }
    func save(close: Bool) {
        guard var value = draft, let url = LinkFile.webURL(value.address) else { return }
        do {
            if let file = value.file {
                guard try LinkFile.readText(from: file) == value.originalText else {
                    error = strings("conflict"); return
                }
            }
            let file = value.file ?? value.folder.appendingPathComponent(UUID().uuidString + ".txt")
            let link = LinkFile(id: file, url: url, title: value.title, notes: value.notes, added: value.added, pinned: value.pinned)
            try link.write()
            value.file = file; value.originalText = link.text
            draft = close ? nil : value
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    func togglePin(_ link: LinkFile) {
        do {
            let text = try LinkFile.readText(from: link.id)
            guard var current = LinkFile(id: link.id, text: text) else { throw CocoaError(.fileReadCorruptFile) }
            current.pinned.toggle()
            current.modified = Date()
            try current.write()
            if draft?.file == link.id, draft?.originalText == text {
                draft?.pinned = current.pinned
                draft?.originalText = current.text
            }
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    func move(_ link: LinkFile) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.directoryURL = root
        panel.prompt = strings("move")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let destination = folder.appendingPathComponent(link.id.lastPathComponent)
            if destination == link.id { return }
            try FileManager.default.moveItem(at: link.id, to: destination)
            if draft?.file == link.id { draft = nil }
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    func trash(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            if let file = draft?.file, file.pathComponents.starts(with: url.pathComponents) { draft = nil }
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    func beginNewFolder(in folder: URL) {
        guard let root else { return }
        var ancestor = folder
        while ancestor.pathComponents.starts(with: root.pathComponents) {
            expanded.insert(ancestor)
            if ancestor == root { break }
            ancestor.deleteLastPathComponent()
        }
        newFolderParent = folder
    }

    func createFolder(in folder: URL, named value: String) {
        guard let name = validFolderName(value) else { return }
        let destination = folder.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            expanded.insert(folder)
            selected = destination
            query = ""
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    func renameFolder(_ folder: URL, to value: String) {
        guard let name = validFolderName(value), folder != root else { return }
        let destination = folder.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
        guard destination != folder else { return }
        do {
            try FileManager.default.moveItem(at: folder, to: destination)
            func relocated(_ url: URL) -> URL {
                guard url.pathComponents.starts(with: folder.pathComponents) else { return url }
                return url.pathComponents.dropFirst(folder.pathComponents.count).reduce(destination) {
                    $0.appendingPathComponent($1, isDirectory: true)
                }
            }
            selected = selected.map(relocated)
            expanded = Set(expanded.map(relocated))
            if let current = draft, current.folder.pathComponents.starts(with: folder.pathComponents) {
                draft?.folder = relocated(current.folder)
                if let file = current.file { draft?.file = relocated(file.deletingLastPathComponent()).appendingPathComponent(file.lastPathComponent) }
            }
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    private func validFolderName(_ value: String) -> String? {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains(":"), !name.contains("\n") else {
            error = strings("invalidName"); return nil
        }
        return name
    }
    func escape() {
        if draft != nil { draft = nil } else { query = "" }
    }
}
