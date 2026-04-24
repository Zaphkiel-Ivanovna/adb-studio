import Foundation
import QuartzCore

final class PointerThrottle {
    private let intervalSeconds: TimeInterval
    private var lastEmitTime: CFTimeInterval = 0

    init(maxRateHz: Double = 120) {
        self.intervalSeconds = 1.0 / maxRateHz
    }

    func shouldEmit() -> Bool {
        let now = CACurrentMediaTime()
        if now - lastEmitTime >= intervalSeconds {
            lastEmitTime = now
            return true
        }
        return false
    }
}
