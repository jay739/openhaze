import Foundation

/// A release on GitHub, as the update check reports it.
struct ReleaseInfo: Equatable {
    let tag: String   // e.g. "v0.3.0"
    let page: URL     // the release page on GitHub
}

/// The ways an update check can fail. Each message says what went wrong and
/// what to do about it.
enum UpdateCheckError: LocalizedError, Equatable {
    case unreachable
    case serverError(status: Int)
    case unreadableResponse

    var errorDescription: String? {
        let fallback = "or look for new versions at \(UpdateChecker.releasesPage.absoluteString)"
        switch self {
        case .unreachable:
            return "OpenHaze couldn't reach GitHub to check for updates. Check your internet connection and try again, \(fallback)."
        case .serverError(let status) where status == 403 || status == 429:
            return "GitHub is limiting update checks from your network right now (HTTP \(status)). Try again in an hour, \(fallback)."
        case .serverError(let status):
            return "GitHub couldn't answer the update check (HTTP \(status)). Try again later, \(fallback)."
        case .unreadableResponse:
            return "GitHub's answer to the update check wasn't a release OpenHaze could read. Try again later, \(fallback)."
        }
    }
}

/// Asks GitHub for the newest OpenHaze release. Notify-only: it never
/// downloads or installs anything; the menu just opens the release page.
enum UpdateChecker {
    static let releasesPage = URL(string: "https://github.com/jay739/openhaze/releases")!
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/jay739/openhaze/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Calls back on the main queue.
    static func fetchLatest(completion: @escaping (Result<ReleaseInfo, UpdateCheckError>) -> Void) {
        var request = URLRequest(url: latestReleaseAPI, timeoutInterval: 15)
        request.setValue("OpenHaze-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<ReleaseInfo, UpdateCheckError>
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failure(.serverError(status: http.statusCode))
            } else if let data, error == nil {
                result = parseRelease(data)
            } else {
                result = .failure(.unreachable)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    static func parseRelease(_ data: Data) -> Result<ReleaseInfo, UpdateCheckError> {
        struct GitHubRelease: Decodable {
            let tagName: String
            let htmlURL: String?
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
              parse(release.tagName) != nil else {
            return .failure(.unreadableResponse)
        }
        // Only ever open a page in this repository, whatever the reply says.
        var page = releasesPage
        if let url = release.htmlURL, url.hasPrefix("https://github.com/jay739/openhaze/"),
           let parsed = URL(string: url) {
            page = parsed
        }
        return .success(ReleaseInfo(tag: release.tagName, page: page))
    }

    /// True when `candidate` (a tag like "v0.3.1") is a later release than
    /// `current`. Numbers compare numerically, a release beats its own
    /// prerelease, and build metadata after "+" is ignored. Anything
    /// unreadable is never newer.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let a = parse(candidate), let b = parse(current) else { return false }
        if a.numbers != b.numbers {
            return b.numbers.lexicographicallyPrecedes(a.numbers)
        }
        switch (a.prerelease, b.prerelease) {
        case (nil, nil): return false
        case (nil, _?): return true
        case (_?, nil): return false
        case let (x?, y?): return x > y
        }
    }

    /// Local builds are 0.0.0; they skip the automatic check.
    static func isDevelopmentBuild(_ version: String) -> Bool {
        parse(version)?.numbers == [0, 0, 0, 0]
    }

    private static func parse(_ version: String) -> (numbers: [Int], prerelease: String?)? {
        var v = Substring(version.trimmingCharacters(in: .whitespaces))
        if v.first == "v" || v.first == "V" { v = v.dropFirst() }
        if let plus = v.firstIndex(of: "+") { v = v[..<plus] }
        var prerelease: String?
        if let dash = v.firstIndex(of: "-") {
            prerelease = String(v[v.index(after: dash)...])
            v = v[..<dash]
        }
        let parts = v.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4 else { return nil }
        var numbers = [0, 0, 0, 0]
        for (i, part) in parts.enumerated() {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), let n = Int(part), n >= 0 else { return nil }
            numbers[i] = n
        }
        return (numbers, prerelease)
    }
}
