import Foundation

@main
struct RenameCheck {
    @MainActor static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let old = root.appendingPathComponent("Before", isDirectory: true)
        let child = old.appendingPathComponent("Child", isDirectory: true)
        let renamed = root.appendingPathComponent("After", isDirectory: true)
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        let file = child.appendingPathComponent("link.txt")
        try "data".write(to: file, atomically: true, encoding: .utf8)
        let library = Library()
        library.root = root
        library.selected = child
        library.expanded = [root, old, child]
        library.draft = Draft(file: file, originalText: "data", folder: child)
        library.renameFolder(old, to: "After")
        let newChild = renamed.appendingPathComponent("Child", isDirectory: true)
        precondition(library.selected == newChild)
        precondition(library.expanded == [root, renamed, newChild])
        precondition(library.draft?.folder == newChild)
        precondition(library.draft?.file == newChild.appendingPathComponent("link.txt"))
        precondition(fm.fileExists(atPath: library.draft!.file!.path))
        library.renameFolder(renamed, to: "bad/name")
        precondition(library.error != nil && fm.fileExists(atPath: renamed.path))
        let collision = root.appendingPathComponent("Taken", isDirectory: true)
        try fm.createDirectory(at: collision, withIntermediateDirectories: false)
        library.error = nil
        library.renameFolder(renamed, to: "Taken")
        precondition(library.error != nil && fm.fileExists(atPath: renamed.path) && fm.fileExists(atPath: collision.path))
        library.error = nil
        library.createFolder(in: renamed, named: "Created")
        let created = renamed.appendingPathComponent("Created", isDirectory: true)
        precondition(fm.fileExists(atPath: created.path) && library.selected == created)
        precondition(library.expanded.contains(renamed))
        library.createFolder(in: renamed, named: "Created")
        precondition(library.error != nil && fm.fileExists(atPath: created.path))
        library.error = nil
        library.createFolder(in: renamed, named: "../Invalid")
        precondition(library.error != nil && !fm.fileExists(atPath: root.appendingPathComponent("Invalid").path))
        library.draft = Draft(folder: root, address: "https://example.com", title: "Move draft")
        library.select(created)
        precondition(library.draft?.folder == created && library.draft?.title == "Move draft")
        library.save(close: true)
        let saved = try fm.contentsOfDirectory(at: created, includingPropertiesForKeys: nil)
        precondition(saved.count == 1 && saved[0].pathExtension == "txt")
        print("PASS: inline folder creation, selection, duplicate and invalid-name handling")
        print("PASS: rename preserves descendants, selection, expansion and draft; invalid names and collisions preserve files")
    }
}
