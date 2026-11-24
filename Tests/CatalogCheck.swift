import Foundation

@main
struct CatalogCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        for name in ["A", "10 Folder", "2 Folder", "A/Nested"] {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let file = root.appendingPathComponent("A/Nested/test.txt")
        let link = LinkFile(id: file, url: LinkFile.webURL("example.com")!, title: "Заголовок", notes: "Первая\n\nВторая\n", added: date, modified: date + 60)
        try link.text.write(to: file, atomically: true, encoding: .utf8)
        precondition(LinkFile(id: file, text: link.text) == link)
        let legacy = link.text.replacingOccurrences(of: "Modified: \(link.modified.ISO8601Format())\n", with: "")
        precondition(LinkFile(id: file, text: legacy)?.modified == date)
        precondition(LinkFile(id: file, text: link.text.replacingOccurrences(of: "Modified: ", with: "Modified: broken")) == nil)
        precondition(LinkFile.webURL("javascript:alert(1)") == nil)
        precondition(LinkFile.webURL("file:///tmp/test") == nil)
        precondition(LinkFile.webURL("https://user:pass@example.com") == nil)
        precondition(link.searchText.contains("вторая"))
        try "unrelated text".write(to: root.appendingPathComponent("other.txt"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: root.appendingPathComponent("A/loop"), withDestinationURL: root)
        let catalog = try Catalog(root: root)
        precondition(catalog.children[root]!.map(\.lastPathComponent) == ["2 Folder", "10 Folder", "A"])
        precondition(catalog.links == [link] && catalog.unreadable == 1)
        precondition(catalog.counts[root] == 1 && catalog.counts[root.appendingPathComponent("A", isDirectory: true)] == 1)
        precondition(link.belongs(to: root.appendingPathComponent("A")))
        precondition(!link.belongs(to: root.appendingPathComponent("A/Nest")))
        var boundary = link
        boundary.notes += String(repeating: "a", count: LinkFile.maximumFileBytes - boundary.text.utf8.count)
        try boundary.write()
        let fullText = try LinkFile.readText(from: file)
        precondition(fullText == boundary.text)
        boundary.notes += "x"
        do {
            try boundary.write()
            preconditionFailure("Oversized save accepted")
        } catch let error as CocoaError { precondition(error.code == .fileReadTooLarge) }
        try boundary.text.write(to: root.appendingPathComponent("oversized.txt"), atomically: true, encoding: .utf8)
        let bounded = try Catalog(root: root)
        precondition(bounded.links == [LinkFile(id: file, text: fullText)!] && bounded.unreadable == 2)
        try link.text.replacingOccurrences(of: "Вторая", with: "Изменено").write(to: file, atomically: true, encoding: .utf8)
        let updated = try Catalog(root: root)
        precondition(updated.links[0].notes.contains("Изменено"))
        let a = LinkFile(id: root.appendingPathComponent("a.txt"), url: link.url, title: "Alpha", notes: "", added: date, modified: date + 3)
        let b = LinkFile(id: root.appendingPathComponent("b.txt"), url: link.url, title: "Beta", notes: "", added: date + 2, modified: date + 1)
        var pinned = LinkFile(id: root.appendingPathComponent("p.txt"), url: link.url, title: "Zulu", notes: "", added: date - 10, modified: date - 10, pinned: true)
        precondition(LinkFile(id: pinned.id, text: pinned.text)?.pinned == true)
        precondition([b, pinned, a].sorted(by: CardSort.created.precedes).map(\.title) == ["Zulu", "Beta", "Alpha"])
        precondition([b, pinned, a].sorted(by: CardSort.modified.precedes).map(\.title) == ["Zulu", "Alpha", "Beta"])
        precondition([b, pinned, a].sorted(by: CardSort.alphabetical.precedes).map(\.title) == ["Zulu", "Alpha", "Beta"])
        pinned.pinned = false
        precondition([b, pinned, a].sorted(by: CardSort.alphabetical.precedes).map(\.title) == ["Alpha", "Beta", "Zulu"])
        precondition(LinkFile(id: pinned.id, text: pinned.text.replacingOccurrences(of: "Pinned: false\n", with: ""))?.pinned == false)
        print("PASS: pin persistence, legacy default, three sorting modes, unpin")
        print("PASS: TXT round trip, legacy format, dates, validation, recursion, sorting, counts, external edits")
    }
}
