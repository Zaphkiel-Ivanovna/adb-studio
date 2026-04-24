import AppKit
import Foundation

struct CoordinateMapper {
    let deviceSize: CGSize

    func map(_ point: NSPoint, in viewSize: CGSize) -> (x: UInt32, y: UInt32)? {
        let devW = deviceSize.width
        let devH = deviceSize.height
        let viewW = viewSize.width
        let viewH = viewSize.height

        guard devW > 0, devH > 0, viewW > 0, viewH > 0 else { return nil }

        let scale = min(viewW / devW, viewH / devH)
        let drawnW = devW * scale
        let drawnH = devH * scale
        let offsetX = (viewW - drawnW) / 2
        let offsetY = (viewH - drawnH) / 2

        let yFromTop = viewH - point.y
        let localX = point.x - offsetX
        let localY = yFromTop - offsetY

        guard localX >= 0, localX <= drawnW, localY >= 0, localY <= drawnH else {
            return nil
        }

        let devX = localX / scale
        let devY = localY / scale

        let clampedX = max(0, min(devW - 1, devX))
        let clampedY = max(0, min(devH - 1, devY))

        return (UInt32(clampedX), UInt32(clampedY))
    }
}
