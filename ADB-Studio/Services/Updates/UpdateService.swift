import Foundation

@MainActor
final class UpdateService: ObservableObject {
    @Published var latestRelease: GitHubRelease?
    @Published var updateAvailable: Bool = false
    @Published var isChecking: Bool = false
    @Published var error: Error?

    private let repoURL = "https://api.github.com/repos/Zaphkiel-Ivanovna/adb-studio/releases/latest"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }

        do {
            guard let url = URL(string: repoURL) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestRelease = release
            updateAvailable = isNewerVersion(release.version, than: currentVersion)
        } catch {
            self.error = error
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newComponents.count, currentComponents.count) {
            let newPart = i < newComponents.count ? newComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        return false
    }
}
