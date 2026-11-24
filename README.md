# Linkord v1.0

[English](#english) · [Русский](#русский) · [Shortcuts / Сочетания клавиш](#shortcuts)

## English

Linkord is a minimalist macOS app for organizing links in folders on your Mac. It follows the product specification in `APP.md` and supports recursive search, a side inspector with autosave, Russian and English, interface scaling, and external file change tracking through FSEvents.

### Build

Requires macOS 14 or later and Command Line Tools for Xcode. The app has no third-party dependencies.

```sh
./script/build_and_run.sh --verify
```

The script checks file storage and change tracking, removes earlier Linkord builds from `dist`, and builds a universal app for Apple Silicon and Intel. Finder handles the disk image layout. The outputs are `dist/Linkord.app` and `dist/Linkord-1.0.dmg`. Local builds use ad hoc signing and do not include Developer ID signing or notarization.

Run `bash scripts/check.sh` for the standalone checks. FSEvents, iconutil, Finder, and hdiutil require a regular macOS session outside the agent sandbox.

### Data

Choose a folder to use as your catalog. Each link is stored in its own UTF-8 text file.

```text
URL: https://example.com
Title: Example
Added: 2026-11-17T00:00:00Z
Modified: 2026-11-17T00:00:00Z
Pinned: false

A description can span multiple lines.
```

For older files without a `Modified` field, Linkord uses the date added. It leaves unsupported text files untouched and displays the number of unreadable items. It skips hidden folders, packages, and symbolic links. Moving or renaming a file preserves existing files at the destination. Deleted items go to the system Trash.

The files on disk are the source of truth. Linkord rebuilds its in-memory search index in the background. UserDefaults stores the last catalog, language, appearance, and zoom level. If a file changes externally during editing, the inspector reports the conflict and preserves the external changes.

## Русский

Минималистичное macOS-приложение для хранения ссылок. Новая реализация по `APP.md`: папки на диске, рекурсивный поиск, правый инспектор, автоматическое сохранение, Ru/En, масштабирование и отслеживание внешних изменений через FSEvents.

### Сборка

macOS 14+, Command Line Tools for Xcode, без сторонних зависимостей.

```sh
./script/build_and_run.sh --verify
```

Скрипт проверяет хранение и отслеживание файлов, удаляет предыдущие артефакты Linkord из `dist`, собирает universal arm64/x86_64 приложение и DMG. Оформление DMG использует Finder. Результат: `dist/Linkord.app` и `dist/Linkord-1.0.dmg`. Для локальной сборки используется ad-hoc подпись, не Developer ID/notarization.

Отдельные проверки: `bash scripts/check.sh`. Системные FSEvents, iconutil, Finder и hdiutil требуют обычного macOS-сеанса без ограничений песочницы агента.

### Данные

Каталог — выбранная пользователем папка. Одна ссылка — один UTF-8 TXT:

```text
URL: https://example.com
Title: Заголовок
Added: 2026-11-17T00:00:00Z
Modified: 2026-11-17T00:00:00Z
Pinned: false

Многострочное описание.
```

Старый формат без `Modified` читается: дата изменения принимается равной дате добавления. Неподходящие TXT не меняются; число непрочитанных элементов отображается в интерфейсе. Скрытые папки, пакеты и симлинки не обходятся. Перемещение и переименование не перезаписывают существующие файлы. Удаление — в системную Корзину.

Файлы — источник истины. Поисковый индекс находится в памяти и пересобирается в фоне. Последний каталог, язык, оформление и масштаб хранятся в UserDefaults. При конфликте внешнего редактирования инспектор сообщает об этом и не перезаписывает изменённый файл.

<a id="shortcuts"></a>

## Keyboard shortcuts / Сочетания клавиш

| Shortcut / Клавиши | English | Русский |
| --- | --- | --- |
| ⌘N | Add a link | Добавить ссылку |
| ⌘⇧N | Create a subfolder | Создать вложенную папку |
| ⌘O | Choose a catalog | Выбрать каталог |
| ⌘+ | Zoom in | Увеличить масштаб |
| ⌘− | Zoom out | Уменьшить масштаб |
| ⌘0 | Reset zoom | Сбросить масштаб |
| Esc | Close the inspector. If already closed, clear the search. | Закрыть инспектор. Если он уже закрыт, очистить поиск. |
