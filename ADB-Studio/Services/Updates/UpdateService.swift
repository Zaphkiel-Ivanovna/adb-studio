import Foundation

@MainActor
final class UpdateService: ObservableObject {
    @Published var latestRelease: GitHubRelease?
    @Published var updateAvailable: Bool = false
    @Published var isChecking: Bool = false
    @Published var error: UpdateError?

    private let repoURL = "https://api.github.com/repos/Zaphkiel-Ivanovna/adb-studio/releases/latest"
    private let allowedDownloadHosts = ["github.com", "objects.githubusercontent.com"]

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        isChecking = true
        error = nil
        defer { isChecking = false }

        do {
            guard let url = URL(string: repoURL) else {
                self.error = .invalidURL
                return
            }

            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                self.error = .invalidResponse
                return
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 403:
                self.error = .rateLimited
                return
            case 404:
                self.error = .releaseNotFound
                return
            default:
                self.error = .httpError(statusCode: httpResponse.statusCode)
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestRelease = release
            updateAvailable = isNewerVersion(release.version, than: currentVersion)
        } catch is DecodingError {
            self.error = .decodingFailed
        } catch let urlError as URLError {
            self.error = .networkError(urlError)
        } catch {
            self.error = .unknown(error)
        }
    }

    func isDownloadURLTrusted(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return false
        }
        return allowedDownloadHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParsed = parseVersion(new)
        let currentParsed = parseVersion(current)

        // Compare numeric parts
        for i in 0..<max(newParsed.numeric.count, currentParsed.numeric.count) {
            let newPart = i < newParsed.numeric.count ? newParsed.numeric[i] : 0
            let currentPart = i < currentParsed.numeric.count ? currentParsed.numeric[i] : 0
            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }

        // If numeric parts are equal, stable > pre-release
        if newParsed.preRelease == nil && currentParsed.preRelease != nil {
            return true
        }

        return false
    }

    private func parseVersion(_ version: String) -> (numeric: [Int], preRelease: String?) {
        // Split by hyphen to separate pre-release suffix (e.g., "1.0.0-beta")
        let parts = version.split(separator: "-", maxSplits: 1)
        let numericString = String(parts[0])
        let preRelease = parts.count > 1 ? String(parts[1]) : nil

        let numeric = numericString.split(separator: ".").compactMap { Int($0) }
        return (numeric, preRelease)
    }
}

// MARK: - Update Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited
    case releaseNotFound
    case httpError(statusCode: Int)
    case decodingFailed
    case networkError(URLError)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .invalidResponse:
            return "Invalid server response"
        case .rateLimited:
            return "GitHub API rate limit exceeded. Please try again later."
        case .releaseNotFound:
            return "No release found"
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .decodingFailed:
            return "Failed to parse release information"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
