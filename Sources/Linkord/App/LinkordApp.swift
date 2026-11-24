import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct LinkordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var library = Library()
    @AppStorage("language") private var language = Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "ru" : "en"
    @AppStorage("zoom") private var zoom = 1.0
    @AppStorage("cardSort") private var cardSort = CardSort.created.rawValue
    @AppStorage("appearance") private var appearance = "system"
    private var strings: L10n { L10n(language: language) }
    private var scheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    var body: some Scene {
        Window("Linkord", id: "catalog") {
            ContentView(library: library, strings: strings, design: Design(scale: zoom))
                .frame(minWidth: Design.minimum.width, minHeight: Design.minimum.height)
                .ignoresSafeArea(.container, edges: .top)
                .preferredColorScheme(scheme)
                .environment(\.locale, strings.locale)
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
