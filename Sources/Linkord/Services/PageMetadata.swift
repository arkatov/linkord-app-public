import Foundation
import CHTML

struct PageMetadata {
    let title: String?
    let description: String?

    let iconHref: String?

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    static func fetch(_ url: URL) async throws -> PageMetadata? {
        var request = URLRequest(url: url)
        request.setValue("text/html, application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              ["text/html", "application/xhtml+xml"].contains(http.mimeType ?? "") else { return nil }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if byte == 62, data.suffix(7).elementsEqual("</head>".utf8) { break }
            if data.count >= 262144 { break }
        }
        try Task.checkCancellation()
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> PageMetadata {
        let utf8 = String(data: data, encoding: .utf8) != nil
        let options = HTML_PARSE_RECOVER.rawValue | HTML_PARSE_NONET.rawValue
            | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue
        let doc = data.withUnsafeBytes { bytes in
            htmlReadMemory(bytes.bindMemory(to: CChar.self).baseAddress, Int32(bytes.count),
                           nil, utf8 ? "UTF-8" : nil, Int32(options))
        }
        guard let doc else { throw URLError(.cannotParseResponse) }
        defer { xmlFreeDoc(doc) }
        func take(_ pointer: UnsafeMutablePointer<xmlChar>?) -> String? {
            guard let pointer else { return nil }
            defer { xmlFree(pointer) }
            let text = String(cString: pointer).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return text.isEmpty ? nil : text
        }
        var title: String?
        var icon: String?
        var tags: [String: String] = [:]
        var head = xmlDocGetRootElement(doc)?.pointee.children
        while let node = head, String(cString: node.pointee.name) != "head" { head = node.pointee.next }
        var child = head?.pointee.children
        while let node = child {
            switch String(cString: node.pointee.name) {
            case "title": title = title ?? take(xmlNodeGetContent(node))
            case "meta":
                if let name = take(xmlGetProp(node, "name")) ?? take(xmlGetProp(node, "property")),
                   let value = take(xmlGetProp(node, "content")) { tags[name.lowercased()] = value }
            case "link":
                if let rel = take(xmlGetProp(node, "rel")), rel.lowercased().split(separator: " ").contains("icon") {
                    icon = icon ?? take(xmlGetProp(node, "href"))
                }
            default: break
            }
            child = node.pointee.next
        }
        return PageMetadata(title: title ?? tags["og:title"] ?? tags["twitter:title"],
                            description: tags["description"] ?? tags["og:description"] ?? tags["twitter:description"],
                            iconHref: icon)
    }
}
