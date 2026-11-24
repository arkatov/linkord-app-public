import AppKit
import SwiftUI

/// AppKit provides Finder-style selection and reliable Return/Escape handling.
struct InlineFolderName: NSViewRepresentable {
    let name: String
    let fontSize: CGFloat
    let label: String
    let finish: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NameField(string: name)
        field.isEditable = true
        field.font = Design.textFont(size: fontSize)
        field.backgroundColor = Design.fieldBackground
        field.focusRingType = .none
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.setAccessibilityLabel(label)
        field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.finish = finish
        field.font = Design.textFont(size: fontSize)
        field.setAccessibilityLabel(label)
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var finish: (String?) -> Void
        private var finished = false
        init(finish: @escaping (String?) -> Void) { self.finish = finish }
        private func complete(_ name: String?) {
            guard !finished else { return }
            finished = true
            finish(name)
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            complete(field.stringValue)
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.cancelOperation(_:)) { complete(nil); return true }
            if selector == #selector(NSResponder.insertNewline(_:)) { complete(control.stringValue); return true }
            return false
        }
    }
}

private final class NameField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window,
                  window.makeFirstResponder(self) else { return }
            self.currentEditor()?.selectAll(nil)
        }
    }
}
