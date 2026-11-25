import SwiftUI

// Every application-owned visual metric lives here; system controls keep native metrics.
struct Design {
    static func textFont(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .regular)
    }
    func font(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static let defaultAccentRGB = 0xB9DDA6
    var scale: CGFloat = 1
    var accentRGB = defaultAccentRGB

    var accent: Color {
        Color(.sRGB, red: Double((accentRGB >> 16) & 255) / 255,
              green: Double((accentRGB >> 8) & 255) / 255, blue: Double(accentRGB & 255) / 255)
    }

    static func rgbValue(for color: Color) -> Int? {
        guard let color = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func channel(_ component: CGFloat) -> Int { Int((min(1, max(0, component)) * 255).rounded()) }
        return (channel(color.redComponent) << 16) | (channel(color.greenComponent) << 8) | channel(color.blueComponent)
    }
    var body: CGFloat { 15 * scale }
    var caption: CGFloat { 12 * scale }
    var title: CGFloat { 16 * scale }
    var icon: CGFloat { 20 * scale }
    var gap: CGFloat { 8 * scale }
    var small: CGFloat { 4 * scale }
    var padding: CGFloat { 16 * scale }
    var radius: CGFloat { 7 * scale }
    var row: CGFloat { 30 * scale }
    var indent: CGFloat { 20 * scale }
    var minimumInspectorWidth: CGFloat { 220 * scale }
    var minimumLinkPaneWidth: CGFloat { 220 * scale }
    var inspector: CGFloat { searchWidth + row + padding + gap + small }
    var searchWidth: CGFloat { 240 * scale }
    var folderGap: CGFloat { 5 * scale }
    var controlGap: CGFloat { 6 * scale }
    var inspectorFieldVerticalPadding: CGFloat { 6 * scale }
    var cardGap: CGFloat { 3 * scale }
    var pathGap: CGFloat { 11 * scale }
    var cardMargin: CGFloat { 10 * scale }
    var panelInset: CGFloat { 20 * scale }
    var headerHeight: CGFloat { 56 * scale }
    var sidebarHeader: CGFloat { 55 * scale }
    var toolbarSymbolHeight: CGFloat { 21 * scale }
    var arrowSize: CGFloat { 10 * scale }
    var arrowWidth: CGFloat { 10 * scale }
    var toolbarTrailing: CGFloat { 15 * scale }
    static let windowControlLeft: CGFloat = 20
    static let windowControlCenterY: CGFloat = 22.5
    static let windowControlGap: CGFloat = 9
    static let rule = Color.primary.opacity(0.10)
    static let resizeRuleFadeDuration = 0.15
    static let resizeRuleHighlight = LinearGradient(
        colors: [.clear, .primary.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom
    )
    static let ruleWidth: CGFloat = 1
    static let window = CGSize(width: 900, height: 620)
    static let minimum = CGSize(width: 760, height: 440)
    static let sidebar: CGFloat = 240
    static let sidebarMin: CGFloat = 170
    static let sidebarMax: CGFloat = 360
    static let dockMenuIconSize = CGSize(width: 16, height: 16)
    static let settingsWidth: CGFloat = 340
    static let descriptionLines = 5...12
    static let minScale = 0.8
    static let maxScale = 1.5
    static let scaleStep = 0.1
    static let darkFormBackground = NSColor(srgbRed: 29 / 255, green: 29 / 255, blue: 29 / 255, alpha: 1)
    static let fieldBackground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkFormBackground : .textBackgroundColor
    }
    static let formBackground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkFormBackground : .clear
    }
    private static func themed(_ dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    static let controlHover = themed(.white, light: .labelColor)
    static let pathName = themed(NSColor(srgbRed: 216/255, green: 216/255, blue: 216/255, alpha: 1), light: .labelColor)
    static let muted = themed(NSColor(srgbRed: 148/255, green: 148/255, blue: 148/255, alpha: 1), light: .secondaryLabelColor)
    static let pathSeparator = Color(nsColor: .tertiaryLabelColor)
    static let selection = Color.primary.opacity(0.10)
}

struct L10n {
    static let defaultLanguage = Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "ru" : "en"
    var language: String
    var locale: Locale { Locale(identifier: language) }
    func callAsFunction(_ key: String) -> String { Self.strings[key]?[language == "ru" ? 0 : 1] ?? key }
    private static let strings: [String: [String]] = [
        "aboutLinkord": ["О программе Linkord", "About Linkord"],
        "clearSearch": ["Очистить поиск", "Clear search"],
        "pin": ["Закрепить", "Pin"], "unpin": ["Открепить", "Unpin"],
        "pinned": ["Закреплено", "Pinned"], "sort": ["Сортировка карточек", "Sort Cards"],
        "created": ["По дате создания", "Date Created"],
        "modified": ["По дате изменения", "Date Modified"],
        "alphabetical": ["По алфавиту", "Alphabetical"],
        "choose": ["Выбрать каталог…", "Choose Catalog…"],
        "welcome": ["Все ссылки — в одном месте", "All your links, in one place"],
        "welcomeDetail": ["Выберите папку для хранения ссылок.", "Choose a folder to store your links."],
        "new": ["Новая ссылка", "New Link"], "edit": ["Редактировать", "Edit"],
        "searchTitle": ["Поиск", "Search"],
        "search": ["Поиск по каталогу", "Search catalog"], "empty": ["Здесь пока нет ссылок", "No links here yet"],
        "noResults": ["Ничего не найдено", "No results"], "title": ["Заголовок", "Title"],
        "url": ["URL", "URL"], "notes": ["Описание", "Description"],
        "loadTitle": ["Загрузить заголовок с сайта", "Load Title from Website"],
        "loadDescription": ["Загрузить описание с сайта", "Load Description from Website"],
        "save": ["Сохранить", "Save"], "cancel": ["Отмена", "Cancel"],
        "openLink": ["Открыть ссылку", "Open Link"], "openWith": ["Открыть в", "Open With"],
        "defaultBrowser": ["%@ (по умолчанию)", "%@ (default)"],
        "openLinkFailed": ["Не удалось открыть ссылку в браузере.", "Couldn’t open the link in a browser."],
        "close": ["Закрыть инспектор", "Close Inspector"], "copy": ["Копировать URL", "Copy URL"],
        "move": ["Перенести в…", "Move To…"], "delete": ["Переместить в Корзину", "Move to Trash"],
        "untitledFolder": ["Новая папка", "New Folder"],
        "newFolder": ["Новая папка…", "New Folder…"], "rename": ["Переименовать…", "Rename…"],
        "name": ["Имя папки", "Folder name"], "folder": ["Папка", "Folder"],
        "showFinder": ["Показать в Finder", "Show in Finder"], "language": ["Язык", "Language"],
        "settings": ["Настройки", "Settings"], "zoomIn": ["Увеличить", "Zoom In"],
        "zoomOut": ["Уменьшить", "Zoom Out"], "zoomReset": ["Фактический размер", "Actual Size"],
        "invalidURL": ["Введите корректный адрес http или https.", "Enter a valid http or https address."],
        "error": ["Не удалось выполнить действие", "Couldn’t Complete Action"], "ok": ["OK", "OK"],
        "invalidName": ["Укажите имя без /, : и начальной точки.", "Enter a name without /, : or a leading dot."],
        "conflict": ["Файл изменён снаружи. Откройте карточку заново, чтобы не потерять изменения.", "The file changed externally. Reopen the card to preserve those changes."],
        "unreadable": ["Не удалось прочитать файлов или папок:", "Files or folders that couldn’t be read:"],
        "loading": ["Загрузка каталога…", "Loading catalog…"],
        "autosave": ["Изменения сохраняются автоматически", "Changes save automatically"],
        "accentColor": ["Акцентный цвет", "Accent Color"],
        "appearance": ["Оформление", "Appearance"], "system": ["Системное", "System"],
        "light": ["Светлое", "Light"], "dark": ["Тёмное", "Dark"]
    ]
}

// Select the property wrapper on Command Line Tools SDKs without the State macro plugin.
typealias ViewState<Value> = SwiftUI.State<Value>

struct HoverControlColor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @ViewState private var isHovered = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isEnabled && isHovered ? Design.controlHover : Design.muted)
            .onHover { isHovered = $0 }
    }
}
