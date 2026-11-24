#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -warnings-as-errors -module-cache-path "$PWD/.build/ModuleCache" Sources/Linkord/Models/LinkFile.swift Tests/CatalogCheck.swift -o .build/catalog-check
.build/catalog-check
swiftc -warnings-as-errors -module-cache-path "$PWD/.build/ModuleCache" Sources/Linkord/Services/FolderWatcher.swift Tests/WatcherCheck.swift -o .build/watcher-check
.build/watcher-check
swiftc -I Sources/CHTML -Xcc -I$(xcrun --show-sdk-path)/usr/include/libxml2 -warnings-as-errors -parse-as-library -module-cache-path "$PWD/.build/ModuleCache" Sources/Linkord/Models/LinkFile.swift Sources/Linkord/Support/Design.swift Sources/Linkord/Services/FolderWatcher.swift Sources/Linkord/Services/PageMetadata.swift Sources/Linkord/Stores/Library.swift Tests/RenameCheck.swift -o .build/rename-check
.build/rename-check
