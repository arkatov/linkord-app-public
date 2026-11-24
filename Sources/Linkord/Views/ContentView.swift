import SwiftUI

struct ContentView: View {
    @ObservedObject var library: Library
    let strings: L10n
    let design: Design
    @AppStorage("folderPaneWidth") private var sidebarWidth = Design.sidebar
    @GestureState private var resizeOffset: CGFloat = 0
    private func clampedWidth(_ width: CGFloat) -> CGFloat { min(Design.sidebarMax, max(Design.sidebarMin, width)) }
    private var isSearching: Bool { !library.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                WindowControlAlignment().frame(height: design.sidebarHeader)
                SidebarView(library: library, strings: strings, design: design)
            }
            .frame(width: clampedWidth(sidebarWidth + resizeOffset) - Design.ruleWidth)
            .overlay(alignment: .trailing) {
                Color.clear.frame(width: design.gap)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .updating($resizeOffset) { value, offset, _ in offset = value.translation.width }
                        .onEnded { sidebarWidth = clampedWidth(sidebarWidth + $0.translation.width) })
            }
            Design.rule.frame(width: Design.ruleWidth)
            VStack(spacing: 0) {
                HStack(spacing: design.controlGap) {
                    Image(systemName: "magnifyingglass")
                            .font(design.font(design.body))
                            .frame(width: design.icon, height: design.toolbarSymbolHeight)
                            .foregroundStyle(.secondary)
                    TextField(strings("searchTitle"), text: $library.query)
                        .textFieldStyle(.plain).accessibilityLabel(strings("search"))
                    if isSearching {
                        Text(library.results.count.formatted()).foregroundStyle(.secondary)
                        Button { library.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel(strings("clearSearch"))
                    }
                    Button(action: library.newLink) {
                        HStack(spacing: design.controlGap) {
                            Image(systemName: "plus.capsule")
                            .font(design.font(design.body))
                            .frame(width: design.icon, height: design.toolbarSymbolHeight)
                            .foregroundStyle(Design.accent)
                            Text(strings("new"))
                        }
                    }.fixedSize().disabled(library.root == nil)
                }
                .buttonStyle(.plain)
                .font(design.font(design.body))
                .padding(.leading, design.cardMargin)
                .padding(.trailing, design.toolbarTrailing)
                .frame(height: design.headerHeight)
                .overlay(alignment: .bottom) { Design.rule.frame(height: Design.ruleWidth) }
                GeometryReader { area in
                    let width = min(design.inspector, area.size.width * Design.inspectorFraction)
                    HStack(spacing: 0) {
                        content.frame(maxWidth: .infinity, maxHeight: .infinity)
                        if library.draft != nil {
                            Divider()
                            InspectorView(library: library, strings: strings, design: design)
                                .frame(width: width)
                        }
                    }
                }
            }
        }
        .foregroundStyle(Design.pathName)
        .background(Color(nsColor: Design.formBackground))
        .ignoresSafeArea(.container, edges: .top)
        .onExitCommand(perform: library.escape)
        .alert(strings("error"), isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button(strings("ok")) { library.error = nil }
        } message: { Text(library.error ?? "") }
    }
    @ViewBuilder private var content: some View {
        if library.root == nil {
            ContentUnavailableView {
                Label(strings("welcome"), systemImage: "link")
            } description: { Text(strings("welcomeDetail")) } actions: {
                Button(strings("choose"), action: library.choose)
            }
        } else if library.loading {
            ProgressView(strings("loading"))
        } else {
            VStack(spacing: 0) {
                if library.catalog.unreadable > 0 {
                    Text("\(strings("unreadable")) \(library.catalog.unreadable)")
                        .font(design.font(design.caption)).foregroundStyle(.secondary).padding(design.gap)
                }
                if library.results.isEmpty {
                    ContentUnavailableView {
                        Label(strings(library.query.isEmpty ? "empty" : "noResults"), systemImage: library.query.isEmpty ? "link" : "magnifyingglass")
                    } actions: {
                        if library.query.isEmpty { Button(strings("new"), action: library.newLink) }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(library.results) { link in
                                LinkCard(link: link, library: library, strings: strings, design: design)
                            }
                        }
                    }
                }
            }
        }
    }
}


// Keep AppKit's original controls, targets, hover behavior and full-screen presentation.
private struct WindowControlAlignment: NSViewRepresentable {
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) { view.needsLayout = true }

    final class Anchor: NSView {
        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            needsLayout = true
        }

        override func layout() {
            super.layout()
            guard let window, !window.styleMask.contains(.fullScreen) else { return }
            var left = Design.windowControlLeft
            for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(kind), let parent = button.superview else { continue }
                let size = button.frame.size
                let rect = NSRect(x: left, y: Design.windowControlCenterY - size.height / 2,
                                  width: size.width, height: size.height)
                button.setFrameOrigin(convert(rect, to: parent).origin)
                left += size.width + Design.windowControlGap
            }
        }
    }
}
