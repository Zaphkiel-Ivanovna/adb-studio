import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let publishedAt: String
    let body: String
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case body
        case assets
    }

    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    var dmgDownloadUrl: String? {
        assets.first { $0.name.hasSuffix(".dmg") }?.browserDownloadUrl
    }
}

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
