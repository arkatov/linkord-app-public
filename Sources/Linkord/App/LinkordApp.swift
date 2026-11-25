import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: Library?
    var showCatalog: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification, object: nil
        )
        if let window = NSApp.keyWindow { updateWindowControls(window) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let library else { return nil }
        let folders = library.recentCatalogs
        guard !folders.isEmpty else { return nil }
        let menu = NSMenu()
        for folder in folders {
            let item = NSMenuItem(title: FileManager.default.displayName(atPath: folder.path),
                                  action: #selector(openRecentCatalog(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = folder
            item.toolTip = folder.path
            let icon = NSWorkspace.shared.icon(forFile: folder.path)
            icon.size = Design.dockMenuIconSize
            item.image = icon
            if folder == library.root { item.state = .on }
            menu.addItem(item)
        }
        return menu
    }

    @objc private func openRecentCatalog(_ sender: NSMenuItem) {
        guard let library, let folder = sender.representedObject as? URL else { return }
        if folder != library.root { library.open(folder) }
        showCatalog?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        updateWindowControls(window)
    }

    private func updateWindowControls(_ window: NSWindow) {
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            let controls: [(NSWindow.ButtonType, NSWindow.StyleMask)] = [
                (.closeButton, .closable), (.miniaturizeButton, .miniaturizable), (.zoomButton, .resizable)
            ]
            for (kind, capability) in controls {
                guard let button = window.standardWindowButton(kind) else { continue }
                button.isHidden = !button.isEnabled || !window.styleMask.contains(capability)
            }
        }
    }
}

@main
struct LinkordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var library = Library()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("language") private var language = L10n.defaultLanguage
    @AppStorage("zoom") private var zoom = 1.0
    @AppStorage("cardSort") private var cardSort = CardSort.created.rawValue
    @AppStorage("accentRGB") private var accentRGB = Design.defaultAccentRGB
    @AppStorage("appearance") private var appearance = "system"
    private var design: Design { Design(scale: zoom, accentRGB: accentRGB) }
    private var accentColor: Binding<Color> {
        Binding(get: { design.accent }, set: { color in
            if let rgb = Design.rgbValue(for: color) { accentRGB = rgb }
        })
    }
    private var strings: L10n { L10n(language: language) }
    private var scheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    var body: some Scene {
        Window("Linkord", id: "catalog") {
            ContentView(library: library, strings: strings, design: design)
                .frame(minWidth: Design.minimum.width, minHeight: Design.minimum.height)
                .ignoresSafeArea(.container, edges: .top)
                .preferredColorScheme(scheme)
                .environment(\.locale, strings.locale)
                .onAppear {
                    delegate.library = library
                    delegate.showCatalog = { openWindow(id: "catalog") }
                }
                .onChange(of: cardSort) { library.filter() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: Design.window.width, height: Design.window.height)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(strings("aboutLinkord")) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(strings("new"), action: library.newLink).keyboardShortcut("n").disabled(library.root == nil)
                Button(strings("newFolder")) {
                    if let folder = library.selected ?? library.root { library.beginNewFolder(in: folder) }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(library.root == nil)
                Button(strings("choose"), action: library.choose).keyboardShortcut("o")
            }
            CommandGroup(after: .toolbar) {
                Button(strings("zoomIn")) { zoom = min(Design.maxScale, zoom + Design.scaleStep) }.keyboardShortcut("+")
                Button(strings("zoomOut")) { zoom = max(Design.minScale, zoom - Design.scaleStep) }.keyboardShortcut("-")
                Button(strings("zoomReset")) { zoom = 1 }.keyboardShortcut("0")
            }
        }
        Settings {
            Form {
                Picker(strings("language"), selection: $language) {
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }
                Picker(strings("sort"), selection: $cardSort) {
                    ForEach(CardSort.allCases, id: \.rawValue) { Text(strings($0.rawValue)).tag($0.rawValue) }
                }
                ColorPicker(strings("accentColor"), selection: accentColor, supportsOpacity: false)
                Picker(strings("appearance"), selection: $appearance) {
                    ForEach(["system", "light", "dark"], id: \.self) { Text(strings($0)).tag($0) }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: Design.formBackground))
            .frame(width: Design.settingsWidth)
            .preferredColorScheme(scheme).environment(\.locale, strings.locale)
        }
    }
}
