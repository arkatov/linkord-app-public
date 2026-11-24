import Foundation

@main
struct WatcherCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var received = false
        let watcher = FolderWatcher(root: root) { received = true }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            try! "External edit".write(to: nested.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        }
        let deadline = Date().addingTimeInterval(4)
        while !received && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        withExtendedLifetime(watcher) { precondition(received, "Nested filesystem changes were not delivered") }
        print("PASS: recursive filesystem watcher receives external writes")
    }
}
