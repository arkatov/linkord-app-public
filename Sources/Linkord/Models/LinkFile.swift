import Foundation

struct LinkFile: Identifiable, Equatable, Sendable {
    let id: URL
    var url: URL
    var title: String
    var notes: String
    var added: Date
    var modified: Date
    var pinned: Bool

    static let maximumFileBytes = 1024 * 1024

    static func readText(from file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        guard try handle.seekToEnd() <= UInt64(maximumFileBytes) else { throw CocoaError(.fileReadTooLarge) }
        try handle.seek(toOffset: 0)
        var data = Data()
        while let chunk = try handle.read(upToCount: maximumFileBytes + 1 - data.count), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maximumFileBytes else { throw CocoaError(.fileReadTooLarge) }
        }
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return text
    }

    func write() throws {
        let contents = text
        guard contents.utf8.count <= Self.maximumFileBytes else { throw CocoaError(.fileReadTooLarge) }
        try contents.write(to: id, atomically: true, encoding: .utf8)
    }

    static func webURL(_ text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: text.contains("://") ? text : "https://" + text),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    init(id: URL, url: URL, title: String, notes: String, added: Date = Date(), modified: Date = Date(), pinned: Bool = false) {
        self.id = id.standardizedFileURL
        self.url = url
        self.title = title.components(separatedBy: .newlines).joined(separator: " ")
        self.notes = notes.replacingOccurrences(of: "\r\n", with: "\n")
        self.added = added
        self.modified = modified
        self.pinned = pinned
    }

    init?(id: URL, text: String) {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard let divider = text.range(of: "\n\n") else { return nil }
        var fields: [String: String] = [:]
        for line in text[..<divider.lowerBound].components(separatedBy: "\n") {
            guard let colon = line.range(of: ": ") else { return nil }
            fields[String(line[..<colon.lowerBound])] = String(line[colon.upperBound...])
        }
        guard let address = fields["URL"], let url = Self.webURL(address),
              let title = fields["Title"], let date = fields["Added"],
              let added = ISO8601DateFormatter().date(from: date) else { return nil }
        let modified: Date
        if let value = fields["Modified"] {
            guard let date = ISO8601DateFormatter().date(from: value) else { return nil }
            modified = date
        } else { modified = added }
        self.init(id: id, url: url, title: title, notes: String(text[divider.upperBound...]), added: added, modified: modified, pinned: fields["Pinned"] == "true")
    }

    var text: String {
        "URL: \(url.absoluteString)\nTitle: \(title)\nAdded: \(added.ISO8601Format())\nModified: \(modified.ISO8601Format())\nPinned: \(pinned)\n\n\(notes)"
    }
    var searchText: String { [title, url.absoluteString, notes].joined(separator: "\n").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
    func belongs(to folder: URL) -> Bool { id.deletingLastPathComponent().pathComponents.starts(with: folder.pathComponents) }
}

struct Catalog: Sendable {
    var folders: [URL] = []
    var links: [LinkFile] = []
    var counts: [URL: Int] = [:]
    var children: [URL: [URL]] = [:]
    var unreadable = 0

    init() {}
    init(root: URL) throws {
        let manager = FileManager.default
        func scan(_ folder: URL) throws {
            folders.append(folder)
            let entries = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .isPackageKey], options: [.skipsHiddenFiles])
                .sorted { a, b in
                    let an = a.lastPathComponent.first?.isNumber == true
                    let bn = b.lastPathComponent.first?.isNumber == true
                    return an != bn ? an : a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                }
            for rawEntry in entries {
                let entry = rawEntry.standardizedFileURL
                let info = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .isPackageKey])
                guard info.isSymbolicLink != true else { continue }
                if info.isDirectory == true && info.isPackage != true {
                    children[folder, default: []].append(entry)
                    do { try scan(entry) } catch { unreadable += 1 }
                } else if info.isRegularFile == true && entry.pathExtension.lowercased() == "txt" {
                    if let text = try? LinkFile.readText(from: entry), let link = LinkFile(id: entry, text: text) { links.append(link) }
                    else { unreadable += 1 }
                }
            }
        }
        try scan(root)
        links.sort { $0.added == $1.added ? $0.id.path < $1.id.path : $0.added > $1.added }
        for link in links {
            var folder = link.id.deletingLastPathComponent()
            while folder.pathComponents.starts(with: root.pathComponents) {
                counts[folder, default: 0] += 1
                if folder == root { break }
                folder.deleteLastPathComponent()
            }
        }
    }
}


enum CardSort: String, CaseIterable {
    case created, modified, alphabetical
    func precedes(_ first: LinkFile, _ second: LinkFile) -> Bool {
        if first.pinned != second.pinned { return first.pinned }
        switch self {
        case .created:
            if first.added != second.added { return first.added > second.added }
        case .modified:
            if first.modified != second.modified { return first.modified > second.modified }
        case .alphabetical:
            let a = first.title.isEmpty ? first.url.host ?? first.url.absoluteString : first.title
            let b = second.title.isEmpty ? second.url.host ?? second.url.absoluteString : second.title
            let order = a.localizedStandardCompare(b)
            if order != .orderedSame { return order == .orderedAscending }
        }
        return first.id.path < second.id.path
    }
}
