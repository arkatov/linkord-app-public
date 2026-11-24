import SwiftUI

struct LinkCard: View {
    let link: LinkFile
    @ObservedObject var library: Library
    let strings: L10n
    let design: Design
    var path: [URL] {
        guard let root = library.root else { return [] }
        var current = root
        var result: [URL] = []
        for component in link.id.deletingLastPathComponent().pathComponents.dropFirst(root.pathComponents.count) {
            current.appendPathComponent(component, isDirectory: true)
            result.append(current)
        }
        return result
    }
    var body: some View {
        HStack(alignment: .top, spacing: design.small) {
            Favicon(url: link.url, design: design)
                .padding(.top, Design.ruleWidth)
            VStack(alignment: .leading, spacing: design.cardGap) {
                Button { NSWorkspace.shared.open(link.url) } label: {
                    Text(link.title.isEmpty ? link.url.host ?? link.url.absoluteString : link.title)
                        .font(.custom("ApercuPro-Regular", fixedSize: design.title))
                        .foregroundStyle(Design.accent).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(.plain)
                if !link.notes.isEmpty {
                    Text(link.notes).font(design.font(design.body)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(link.url.absoluteString).font(design.font(design.caption))
                    .foregroundStyle(Design.muted).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !path.isEmpty {
                    // One wrapping attributed path keeps deep folders usable at narrow widths.
                    breadcrumbs.tint(Design.pathName).font(design.font(design.caption))
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.scheme == "linkord-folder", let index = Int(url.host ?? ""), path.indices.contains(index) else { return .discarded }
                            library.select(path[index]); return .handled
                        })
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, design.pathGap - design.cardGap)
                }

            }.frame(maxWidth: .infinity, alignment: .leading)
            if link.pinned {
                Button { library.togglePin(link) } label: {
                    Image(systemName: "pin")
                        .font(.system(size: design.caption))
                        .frame(width: design.icon, height: design.icon)
                        .foregroundStyle(Design.accent)
                }.buttonStyle(.plain).accessibilityLabel(strings("unpin"))
            }
        }
        .padding(.vertical, design.cardMargin)
        .safeAreaInset(edge: .bottom, spacing: 0) { Design.rule.frame(height: Design.ruleWidth) }
        .padding(.horizontal, design.cardMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(strings(link.pinned ? "unpin" : "pin")) { library.togglePin(link) }
            Divider()
            Button(strings("copy")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
            }
            Button(strings("edit")) { library.edit(link) }
            Button(strings("move")) { library.move(link) }
            Divider()
            Button(strings("delete")) { library.trash(link.id) }
        }
    }
    private var breadcrumbs: Text {
        var text = Text("")
        for (index, folder) in path.enumerated() {
            if index > 0 {
                text = text + Text(" › ").foregroundColor(Design.pathSeparator)
            }
            var name = AttributedString(folder.lastPathComponent)
            name.link = URL(string: "linkord-folder://\(index)")
            name.foregroundColor = Design.pathName
            text = text + Text(name)
        }
        return text
    }
}
