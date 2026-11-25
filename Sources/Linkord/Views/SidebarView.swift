import SwiftUI

struct SidebarView: View {
    @ObservedObject var library: Library
    let strings: L10n
    let design: Design
    var visibleFolders: [(url: URL, depth: Int)] {
        guard let root = library.root else { return [] }
        var rows: [(URL, Int)] = []
        func append(_ folder: URL, depth: Int) {
            rows.append((folder, depth))
            if library.expanded.contains(folder) {
                for child in library.catalog.children[folder] ?? [] { append(child, depth: depth + 1) }
            }
        }
        append(root, depth: 0)
        return rows
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleFolders, id: \.url) { row in
                    FolderRow(library: library, folder: row.url, depth: row.depth, isSelected: library.newFolderParent == nil && library.selected == row.url, strings: strings, design: design) {
                        library.beginNewFolder(in: row.url)
                    }
                    if library.newFolderParent == row.url {
                        HStack(spacing: design.controlGap) {
                            Color.clear.frame(width: design.gap)
                            Image(systemName: "folder").font(.system(size: design.icon)).foregroundStyle(Design.accent)
                            InlineFolderName(name: strings("untitledFolder"), fontSize: design.body, label: strings("name")) { name in
                                library.newFolderParent = nil
                                if let name { library.createFolder(in: row.url, named: name) }
                            }
                        }
                        .padding(.leading, design.gap + CGFloat(row.depth + 1) * design.indent)
                        .padding(.trailing, design.caption)
                        .frame(height: design.row)
                        .background(Design.selection)
                    }
                }
            }
        }
        .onChange(of: library.root) { library.newFolderParent = nil }
        .frame(minWidth: Design.sidebarMin, idealWidth: Design.sidebar, maxWidth: Design.sidebarMax)
    }
}

private struct FolderRow: View {
    @ObservedObject var library: Library
    let folder: URL
    let depth: Int
    let isSelected: Bool
    let strings: L10n
    let design: Design
    let newFolder: () -> Void
    @ViewState private var renaming = false
    private var isRoot: Bool { folder == library.root }
    var body: some View {
        HStack(spacing: design.folderGap) {
            Image(systemName: library.expanded.contains(folder) ? "chevron.down" : "chevron.right")
                .font(.system(size: design.arrowSize, weight: .light))
                .foregroundStyle(.secondary)
                .opacity(library.catalog.children[folder, default: []].isEmpty ? 0 : 1)
                .frame(width: design.arrowWidth)
            Image(systemName: isRoot ? "folder.fill" : "folder").font(design.font(design.body)).frame(width: design.icon, height: design.icon).foregroundStyle(Design.accent)
                .padding(.trailing, design.controlGap - design.folderGap)
            if renaming {
                InlineFolderName(name: folder.lastPathComponent, fontSize: design.body, label: strings("name")) { name in
                    renaming = false
                    if let name { library.renameFolder(folder, to: name) }
                }
            } else {
                Text(folder.lastPathComponent)
                    .font(design.font(design.body))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 0)
            Text("\(library.catalog.counts[folder, default: 0])")
                .font(design.font(design.caption)).foregroundStyle(.tertiary)
        }
        .padding(.leading, design.cardMargin + CGFloat(depth) * design.indent)
        .padding(.trailing, design.caption)
        .frame(height: design.row)
        .background(isSelected ? Design.selection : .clear)
        .contentShape(Rectangle())
        .onTapGesture { if !renaming { library.select(folder, toggle: true) } }
        .contextMenu { actions }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { library.select(folder, toggle: true) }
    }
    @ViewBuilder private var actions: some View {
        if isRoot { Button(strings("choose"), action: library.choose) }
        Button(strings("newFolder")) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: newFolder)
        }
        if !isRoot {
            Button(strings("rename")) {
                // Let the context menu restore focus before creating the inline editor.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    library.selected = folder
                    renaming = true
                }
            }
            Button(strings("delete")) { library.trash(folder) }
        }
        Button(strings("showFinder")) { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
    }
}
