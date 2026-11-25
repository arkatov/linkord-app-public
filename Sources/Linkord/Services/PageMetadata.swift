import Foundation
import NaturalLanguage
import CHTML

struct PageMetadata {
    let title: String?
    let description: String?

    let iconHref: String?
    let language: String?
    let alternates: [String: URL]

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    static func fetchLocalized(_ url: URL, language: String) async throws -> PageMetadata? {
        let preferred = language == "ru" ? "ru" : "en"
        let fallback = preferred == "ru" ? "en" : "ru"
        guard let page = try await fetch(url, acceptLanguage: "\(preferred), \(fallback);q=0.8") else { return nil }
        let languages = page.language == preferred ? [fallback] : [preferred, fallback]
        var result = page.supportedText
        for language in languages {
            let preferAlternate = language == preferred && page.language != preferred
            if result.title != nil, result.description != nil, !preferAlternate { break }
            guard let alternate = page.alternates[language], alternate != url,
                  let localized = try? await fetch(alternate, acceptLanguage: language) else { continue }
            try Task.checkCancellation()
            let text = localized.supportedText
            let first = preferAlternate ? text : result
            let second = preferAlternate ? result : text
            result = PageMetadata(title: first.title ?? second.title, description: first.description ?? second.description,
                                  iconHref: page.iconHref, language: first.language, alternates: [:])
        }
        try Task.checkCancellation()
        return result
    }

    var supportedText: PageMetadata {
        func supported(_ text: String?) -> String? {
            guard let text else { return nil }
            if text.split(whereSeparator: { $0.isWhitespace }).count >= 4 {
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(text)
                if let detected = recognizer.dominantLanguage,
                   recognizer.languageHypotheses(withMaximum: 1)[detected, default: 0] >= 0.65 {
                    return detected == .english || detected == .russian ? text : nil
                }
            }
            return language == nil || language == "en" || language == "ru" ? text : nil
        }
        return PageMetadata(title: supported(title), description: supported(description),
                            iconHref: iconHref, language: language, alternates: alternates)
    }

    static func fetch(_ url: URL, acceptLanguage: String? = nil) async throws -> PageMetadata? {
        var request = URLRequest(url: url)
        request.setValue("text/html, application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")
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
        return try parse(data, baseURL: http.url, contentLanguage: http.value(forHTTPHeaderField: "Content-Language"))
    }

    static func parse(_ data: Data, baseURL: URL? = nil, contentLanguage: String? = nil) throws -> PageMetadata {
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
        func languageCode(_ value: String?) -> String? {
            value?.lowercased().split(whereSeparator: { "-_, ".contains($0) }).first.map(String.init)
        }
        var alternates: [String: URL] = [:]
        var title: String?
        var icon: String?
        var tags: [String: String] = [:]
        let html = xmlDocGetRootElement(doc)
        let htmlLanguage = html.flatMap { take(xmlGetProp($0, "lang")) }
        var head = html?.pointee.children
        while let node = head, String(cString: node.pointee.name) != "head" { head = node.pointee.next }
        var child = head?.pointee.children
        while let node = child {
            switch String(cString: node.pointee.name) {
            case "title": title = title ?? take(xmlNodeGetContent(node))
            case "meta":
                if let name = take(xmlGetProp(node, "name")) ?? take(xmlGetProp(node, "property")),
                   let value = take(xmlGetProp(node, "content")) { tags[name.lowercased()] = value }
            case "link":
                guard let rel = take(xmlGetProp(node, "rel")), let href = take(xmlGetProp(node, "href")) else { break }
                let relations = rel.lowercased().split(separator: " ")
                if relations.contains("icon") { icon = icon ?? href }
                if relations.contains("alternate"), let code = languageCode(take(xmlGetProp(node, "hreflang"))),
                   code == "en" || code == "ru",
                   let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                   let url = LinkFile.webURL(resolved.absoluteString), resolved.host != nil {
                    alternates[code] = alternates[code] ?? url
                }
            default: break
            }
            child = node.pointee.next
        }
        return PageMetadata(title: title ?? tags["og:title"] ?? tags["twitter:title"],
                            description: tags["description"] ?? tags["og:description"] ?? tags["twitter:description"],
                            iconHref: icon, language: languageCode(htmlLanguage ?? contentLanguage ?? tags["og:locale"]),
                            alternates: alternates)
    }
}
