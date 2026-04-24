import SwiftUI
import AVFoundation
import CoreMedia

final class SampleBufferRenderer: ObservableObject {
    let layer = AVSampleBufferDisplayLayer()

    init() {
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if Thread.isMainThread {
            performEnqueue(sampleBuffer)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performEnqueue(sampleBuffer)
            }
        }
    }

    func flush() {
        if Thread.isMainThread {
            layer.flush()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.layer.flush()
            }
        }
    }

    private func performEnqueue(_ sampleBuffer: CMSampleBuffer) {
        if layer.status == .failed {
            layer.flush()
        }
        if layer.isReadyForMoreMediaData {
            layer.enqueue(sampleBuffer)
        }
    }
}

struct SampleBufferView: NSViewRepresentable {
    let renderer: SampleBufferRenderer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let hostLayer = CALayer()
        hostLayer.backgroundColor = NSColor.black.cgColor
        view.layer = hostLayer
        renderer.layer.frame = view.bounds
        renderer.layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        hostLayer.addSublayer(renderer.layer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        renderer.layer.frame = nsView.bounds
    }
}
