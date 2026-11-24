import AppKit
import CryptoKit
import SwiftUI

actor FaviconCache {
    static let shared = FaviconCache()
    private var failed: Set<String> = []
    private var pending: [String: Task<Data?, Never>] = [:]
    func data(for url: URL) async -> Data? {
        guard var origin = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        origin.path = "/favicon.ico"; origin.query = nil; origin.fragment = nil
        guard let icon = origin.url else { return nil }
        let key = SHA256.hash(data: Data(icon.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.arkatov.linkord/Favicons", isDirectory: true)
        let file = folder.appendingPathComponent(key)
        if let data = try? Data(contentsOf: file) { return data }
        if failed.contains(key) { return nil }
        if let task = pending[key] { return await task.value }
        let task = Task<Data?, Never> {
            var data = await Self.download(icon)
            if data == nil, let metadata = try? await PageMetadata.fetch(url),
               let href = metadata.iconHref, let declared = URL(string: href, relativeTo: url)?.absoluteURL,
               ["http", "https"].contains(declared.scheme?.lowercased() ?? ""), declared != icon {
                data = await Self.download(declared)
            }
            guard let data else { return nil }
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return data
        }
        pending[key] = task
        let data = await task.value
        pending[key] = nil
        if data == nil { failed.insert(key) }
        return data
    }
    private static func download(_ url: URL) async -> Data? {
        do {
            let (bytes, response) = try await PageMetadata.session.bytes(for: URLRequest(url: url, timeoutInterval: 8))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.mimeType != "text/html" else { return nil }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 2_000_000 else { return nil }
                data.append(byte)
            }
            return NSImage(data: data) == nil ? nil : data
        } catch { return nil }
    }
}

struct Favicon: View {
    let url: URL
    let design: Design
    @ViewState private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "pointer.arrow.ipad.rays").font(design.font(design.body)).foregroundStyle(Design.accent) }
        }
        .frame(width: design.icon, height: design.icon)
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            if let data = await FaviconCache.shared.data(for: url), !Task.isCancelled { image = NSImage(data: data) }
        }
    }
}
