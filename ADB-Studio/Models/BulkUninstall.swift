import Foundation

struct BulkUninstallFailure: Identifiable, Equatable {
    let packageName: String
    let displayName: String
    let message: String

    var id: String { packageName }
}

enum BulkUninstallPhase: Equatable {
    case confirming
    case running(current: Int, total: Int, appName: String)
    case finished(succeeded: Int, failures: [BulkUninstallFailure], skipped: Int)
}
