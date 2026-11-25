import SwiftUI

struct InspectorView: View {
    @ObservedObject var library: Library
    let strings: L10n
    let design: Design
    @FocusState private var focusedField: String?

    private func binding(_ key: WritableKeyPath<Draft, String>) -> Binding<String> {
        Binding(get: { library.draft?[keyPath: key] ?? "" }, set: { value in
            library.updateDraft(key, to: value)
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: design.padding) {
            HStack {
                Text(strings(library.draft?.file == nil ? "new" : "edit")).font(design.font(design.body))
                Spacer()
                Button { library.draft = nil } label: { Image(systemName: "xmark").font(.system(size: design.icon)).foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help(strings("close")).accessibilityLabel(strings("close"))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: design.padding) {
                    if let draft = library.draft {
                        let components = draft.folder.pathComponents.dropFirst(library.root?.pathComponents.count ?? 0)
                        Label {
                            let names = components.isEmpty ? [draft.folder.lastPathComponent] : Array(components)
                            names.enumerated().reduce(Text("")) { path, element in
                                let prefix = element.offset == 0 ? path : path + Text(" › ").foregroundColor(Design.pathSeparator)
                                return prefix + Text(verbatim: element.element).foregroundColor(Design.pathName)
                            }.font(design.font(design.caption)).fixedSize(horizontal: false, vertical: true)
                        } icon: { Image(systemName: "folder").foregroundStyle(.secondary) }
                    }
                    field("url", key: \.address)
                    field("title", key: \.title, metadata: \.title)
                    VStack(alignment: .leading, spacing: design.gap) {
                        fieldLabel("notes", key: \.notes, metadata: \.description)
                        TextField("", text: binding(\.notes), axis: .vertical)
                            .accessibilityLabel(strings("notes"))
                            .lineLimit(Design.descriptionLines).modifier(InspectorFieldStyle(design: design))
                    }
                    if let draft = library.draft {
                        if LinkFile.webURL(draft.address) == nil && !draft.address.isEmpty {
                            Text(strings("invalidURL")).font(design.font(design.caption)).foregroundStyle(.secondary)
                        }
                        if draft.file == nil {
                            HStack {
                                Button(strings("cancel")) { library.draft = nil }
                                Spacer()
                                Button(strings("save")) { library.save(close: true) }
                                    .disabled(LinkFile.webURL(draft.address) == nil)
                                    .keyboardShortcut(.return, modifiers: .command)
                            }
                        } else { Text(strings("autosave")).font(design.font(design.caption)).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .font(design.font(design.body))
        .padding(design.padding)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: Design.formBackground))
    }
    private func field(
        _ key: String, key path: WritableKeyPath<Draft, String>,
        metadata: KeyPath<PageMetadata, String?>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: design.gap) {
            fieldLabel(key, key: path, metadata: metadata)
            TextField("", text: binding(path))
                .focused($focusedField, equals: key)
                .offset(y: focusedField == key ? design.fieldEditorOffset : 0)
                .accessibilityLabel(strings(key))
                .modifier(InspectorFieldStyle(design: design))
        }
    }

    private func fieldLabel(
        _ key: String, key path: WritableKeyPath<Draft, String>,
        metadata: KeyPath<PageMetadata, String?>?
    ) -> some View {
        HStack {
            Text(strings(key)).font(design.font(design.caption))
            if let metadata {
                let label = strings(key == "title" ? "loadTitle" : "loadDescription")
                Spacer()
                Button {
                    Task { await library.loadMetadata(metadata, into: path) }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(design.font(design.body))
                }
                .buttonStyle(.plain)
                .disabled(library.draft.flatMap { LinkFile.webURL($0.address) } == nil)
                .help(label)
                .accessibilityLabel(label)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct InspectorFieldStyle: ViewModifier {
    let design: Design
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .padding(.horizontal, design.gap)
            .padding(.vertical, design.small)
            .background(Color(nsColor: Design.fieldBackground), in: RoundedRectangle(cornerRadius: design.radius))
            .overlay { RoundedRectangle(cornerRadius: design.radius).strokeBorder(Color(nsColor: .separatorColor)).allowsHitTesting(false) }
    }
}
