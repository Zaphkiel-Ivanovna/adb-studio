import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolved: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                onResolved(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onResolved(window)
        }
    }
}
