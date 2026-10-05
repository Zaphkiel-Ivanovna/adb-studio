import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

enum ChangelogError: LocalizedError {
    case usage
    case git(arguments: [String], message: String)
    case missingRepository
    case unreadableNotesFile(String)
    case api(String)
    case invalidNotes([String])

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: changelog.swift <tag> [--no-ai] [--notes <file.json>]."
        case .git(let arguments, let message):
            return "git \(arguments.joined(separator: " ")) failed: \(message)."
        case .missingRepository:
            return "Unable to determine the GitHub repository; set GITHUB_REPOSITORY=owner/name."
        case .unreadableNotesFile(let path):
            return "Unable to read the notes file at \(path)."
        case .api(let message):
            return "The DeepSeek request failed: \(message)."
        case .invalidNotes(let problems):
            return "The generated notes are invalid: \(problems.joined(separator: "; "))."
        }
    }
}

enum Section: String, CaseIterable, Encodable {
    case added, changed, deprecated, removed, fixed, security

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    init?(changeType: String, emoji: String) {
        switch changeType {
        case "feat":
            self = .added
        case "fix", "validation":
            self = .fixed
        case "security", "auth":
            self = .security
        case "ui", "performance", "error-handling":
            self = .changed
        case "style" where emoji.hasPrefix("💄"):
            self = .changed
        default:
            return nil
        }
    }
}

struct Change {
    let emoji: String
    let type: String
    let scope: String?
    let text: String
    let pullRequest: Int?

    var section: Section? {
        Section(changeType: type, emoji: emoji)
    }

    var label: String {
        scope.map { "\(type)(\($0)): \(text)" } ?? "\(type): \(text)"
    }

    init?(line: String) {
        let pattern = #"^\s*(?:\*\s+)?([^\x00-\x7F]\S*)\s+([a-z][a-z-]*)(?:\(([^)]*)\))?:\s+(.+?)\s*$"#
        guard let groups = captures(of: pattern, in: line),
            let emoji = groups[0], let type = groups[1], let rawText = groups[3]
        else { return nil }
        let pullRequestGroups = captures(of: #"^(.*?)\s*\(#(\d+)\)$"#, in: rawText)
        self.emoji = emoji
        self.type = type
        self.scope = groups[2]
        self.text = pullRequestGroups?[0] ?? rawText
        self.pullRequest = pullRequestGroups?[1].flatMap { Int($0) }
    }
}

struct Commit {
    let sha: String
    let shortSha: String
    let pullRequest: Int?
    let headline: Change
    let details: [Change]
    let section: Section

    var userFacingChange: Change {
        headline.section != nil ? headline : details.first { $0.section != nil } ?? headline
    }
}

struct ReleaseContext {
    let repository: String
    let tag: String
    let previousTag: String?
    let commits: [Commit]

    var version: String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }
}

struct NoteItem: Decodable {
    let text: String
    let commits: [String]
}

struct ReleaseNotes: Decodable {
    var summary = ""
    var sections: [Section: [NoteItem]] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        summary = try container.decodeIfPresent(String.self, forKey: AnyKey("summary")) ?? ""
        for section in Section.allCases {
            sections[section] = try container.decodeIfPresent([NoteItem].self, forKey: AnyKey(section.rawValue)) ?? []
        }
    }

    func items(in section: Section) -> [NoteItem] {
        sections[section] ?? []
    }

    mutating func append(_ item: NoteItem, to section: Section) {
        sections[section, default: []].append(item)
    }
}

struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

struct ChatMessage: Encodable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    struct ResponseFormat: Encodable {
        let type: String
    }

    struct Thinking: Encodable {
        let type: String
    }

    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat
    let thinking: Thinking
    let maxTokens: Int
    let temperature: Double
}

struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message?
        let finishReason: String?
    }

    let choices: [Choice]
}

struct PromptPayload: Encodable {
    struct Entry: Encodable {
        let id: String
        let section: Section
        let title: String
        let details: [String]
    }

    let version: String
    let changes: [Entry]
}

let systemPrompt = """
    You write the release notes of ADB Studio, a native macOS app for managing Android devices over ADB \
    (device list, Wi-Fi pairing, screen mirroring, app management, port forwarding and device tools).

    You receive a JSON object listing the changes of one release. Each change has an id, a suggested section, \
    a title and implementation details written by the developer.

    Write the notes for the people who use the app:
    - Describe what users can now do or what behaves differently, never how it is implemented. Leave out type \
    names, file names, APIs, frameworks and internal refactors.
    - Use only the information provided. Do not invent features, numbers or platforms.
    - Each item is a single concise sentence of at most 30 words in plain English, starting with a capital \
    letter and ending with a period.
    - Group several changes into one item when they describe the same user-facing improvement, and cite all \
    their ids.
    - Every change id must be cited by at least one item. Cite ids exactly as given.
    - Use the suggested section unless it is clearly wrong. Allowed sections: added, changed, deprecated, \
    removed, fixed, security.
    - No Markdown, links, HTML, emoji or @mentions.
    - "summary" is one or two sentences presenting the highlights of the release, or an empty string when the \
    release only contains minor changes.

    Answer with a json object of exactly this shape, using an empty array for sections without items:
    {"summary": "...", "added": [{"text": "...", "commits": ["abc1234"]}], "changed": [], "deprecated": [], \
    "removed": [], "fixed": [], "security": []}
    """

func captures(of pattern: String, in text: String) -> [String?]? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return (1..<match.numberOfRanges).map { index in
        Range(match.range(at: index), in: text).map { String(text[$0]) }
    }
}

func warn(_ message: String) {
    let isGitHubActions = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    let line = isGitHubActions ? "::warning::\(message)\n" : "warning: \(message)\n"
    FileHandle.standardError.write(Data(line.utf8))
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

func git(_ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        throw ChangelogError.git(arguments: arguments, message: message)
    }
    return String(decoding: data, as: UTF8.self)
}

func repositorySlug() throws -> String {
    if let repository = ProcessInfo.processInfo.environment["GITHUB_REPOSITORY"], !repository.isEmpty {
        return repository
    }
    let remote = try git(["remote", "get-url", "origin"]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let groups = captures(of: #"github\.com[:/]([^/]+)/(.+?)(?:\.git)?$"#, in: remote),
        let owner = groups[0], let name = groups[1]
    else { throw ChangelogError.missingRepository }
    return "\(owner)/\(name)"
}

func previousTag(before tag: String) throws -> String? {
    guard (try? git(["rev-parse", "--verify", "--quiet", "\(tag)^"])) != nil else { return nil }
    let includesPrereleases = tag.contains("-")
    return try git(["tag", "--merged", "\(tag)^", "--list", "v*", "--sort=-v:refname"])
        .split(separator: "\n")
        .map(String.init)
        .first { $0 != tag && (includesPrereleases || !$0.contains("-")) }
}

func pullRequestNumbers(in range: String) throws -> [String: Int] {
    var numbers: [String: Int] = [:]
    for line in try git(["log", "--merges", "--format=%H%x1f%s", range]).split(separator: "\n") {
        let fields = line.split(separator: "\u{1f}", maxSplits: 1).map(String.init)
        guard fields.count == 2,
            let number = captures(of: #"^Merge pull request #(\d+)"#, in: fields[1])?[0].flatMap({ Int($0) })
        else { continue }
        for sha in try git(["rev-list", "\(fields[0])^1..\(fields[0])^2"]).split(separator: "\n") {
            numbers[String(sha)] = numbers[String(sha)] ?? number
        }
    }
    return numbers
}

func messageLines(_ message: String) -> [String] {
    message
        .replacingOccurrences(of: #"\s+\*\s+(?=[^\x00-\x7F])"#, with: "\n* ", options: .regularExpression)
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

func userFacingCommits(in range: String, pullRequests: [String: Int]) throws -> [Commit] {
    var commits: [Commit] = []
    let output = try git(["log", "--no-merges", "--reverse", "--format=%H%x1f%an%x1f%B%x1e", range])
    for record in output.split(separator: "\u{1e}") {
        let fields = record.trimmingCharacters(in: .newlines).split(separator: "\u{1f}", maxSplits: 2).map(String.init)
        guard fields.count == 3, !fields[1].hasSuffix("[bot]") else { continue }
        let sha = fields[0]
        let shortSha = String(sha.prefix(7))
        let lines = messageLines(fields[2])
        guard let firstLine = lines.first else { continue }
        guard let headline = Change(line: firstLine) else {
            warn("Skipped \(shortSha), its message does not follow the gitmoji convention: \(firstLine)")
            continue
        }
        let details = lines.dropFirst().filter { $0.hasPrefix("* ") }.compactMap { Change(line: $0) }
        guard let section = headline.section ?? details.lazy.compactMap({ $0.section }).first else { continue }
        commits.append(
            Commit(
                sha: sha,
                shortSha: shortSha,
                pullRequest: pullRequests[sha] ?? headline.pullRequest,
                headline: headline,
                details: details,
                section: section
            )
        )
    }
    return commits
}

func fallbackNotes(for commits: [Commit]) -> ReleaseNotes {
    var notes = ReleaseNotes()
    for commit in commits {
        notes.append(NoteItem(text: commit.userFacingChange.text, commits: [commit.shortSha]), to: commit.section)
    }
    return notes
}

func validationProblems(in notes: ReleaseNotes, commits: [Commit]) -> [String] {
    let forbiddenPatterns = [#"https?://"#, #"\]\("#, "[<>]", #"(^|\s)@\w"#]
    let containsForbiddenMarkup = { (text: String) in
        forbiddenPatterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }
    let knownIds = Set(commits.map(\.shortSha))
    var citedIds = Set<String>()
    var problems: [String] = []

    if notes.summary.count > 400 || notes.summary.contains("\n") || containsForbiddenMarkup(notes.summary) {
        problems.append("the summary must be at most 400 characters on one line, without links, HTML or mentions")
    }
    for section in Section.allCases {
        for item in notes.items(in: section) {
            let text = item.text.trimmingCharacters(in: .whitespaces)
            if text.isEmpty || text.count > 300 || text.contains("\n") {
                problems.append("each \(section.rawValue) item needs one line of text of at most 300 characters")
            }
            if containsForbiddenMarkup(text) {
                problems.append("\"\(text)\" contains a link, HTML or a mention")
            }
            if item.commits.isEmpty {
                problems.append("\"\(text)\" cites no change id")
            }
            for id in item.commits where !knownIds.contains(id) {
                problems.append("\"\(text)\" cites the unknown change id \(id)")
            }
            citedIds.formUnion(item.commits)
        }
    }
    let missingIds = knownIds.subtracting(citedIds).sorted()
    if !missingIds.isEmpty {
        problems.append("these change ids are not cited: \(missingIds.joined(separator: ", "))")
    }
    return problems
}

func decodeNotes(_ data: Data, commits: [Commit]) throws -> ReleaseNotes {
    guard let notes = try? JSONDecoder().decode(ReleaseNotes.self, from: data) else {
        throw ChangelogError.invalidNotes(["the answer is not a JSON object with the requested shape"])
    }
    let problems = validationProblems(in: notes, commits: commits)
    guard problems.isEmpty else { throw ChangelogError.invalidNotes(problems) }
    return notes
}

func requestCompletion(messages: [ChatMessage], apiKey: String, model: String) async throws -> String {
    guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
        throw ChangelogError.api("invalid endpoint")
    }
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(
        ChatRequest(
            model: model,
            messages: messages,
            responseFormat: .init(type: "json_object"),
            thinking: .init(type: "disabled"),
            maxTokens: 4096,
            temperature: 0.3
        )
    )

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 120
    let (data, response) = try await URLSession(configuration: configuration).data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw ChangelogError.api("no HTTP response")
    }
    guard httpResponse.statusCode == 200 else {
        let body = String(decoding: data.prefix(300), as: UTF8.self)
        throw ChangelogError.api("HTTP \(httpResponse.statusCode) \(body)")
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let completion = try decoder.decode(ChatResponse.self, from: data)
    guard let choice = completion.choices.first, let content = choice.message?.content, !content.isEmpty else {
        throw ChangelogError.api("empty answer")
    }
    guard choice.finishReason == "stop" else {
        throw ChangelogError.api("answer interrupted (\(choice.finishReason ?? "unknown reason"))")
    }
    return content
}

func generatedNotes(for context: ReleaseContext, apiKey: String, model: String) async throws -> ReleaseNotes {
    let payload = PromptPayload(
        version: context.version,
        changes: context.commits.map { commit in
            PromptPayload.Entry(
                id: commit.shortSha,
                section: commit.section,
                title: commit.headline.label,
                details: commit.details.map(\.label)
            )
        }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var messages = [
        ChatMessage(role: "system", content: systemPrompt),
        ChatMessage(role: "user", content: String(decoding: try encoder.encode(payload), as: UTF8.self)),
    ]

    var lastProblems: [String] = []
    for attempt in 1...2 {
        let answer = try await requestCompletion(messages: messages, apiKey: apiKey, model: model)
        do {
            let notes = try decodeNotes(Data(answer.utf8), commits: context.commits)
            log("Release notes written by \(model) on attempt \(attempt).")
            return notes
        } catch ChangelogError.invalidNotes(let problems) {
            lastProblems = problems
            messages.append(ChatMessage(role: "assistant", content: answer))
            messages.append(
                ChatMessage(
                    role: "user",
                    content: "Your json is invalid:\n- \(problems.joined(separator: "\n- "))\nAnswer with the corrected json object only."
                )
            )
        }
    }
    throw ChangelogError.invalidNotes(lastProblems)
}

func escaped(_ text: String) -> String {
    text
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: #"(?<![\w`])@(\w+)"#, with: "`@$1`", options: .regularExpression)
}

func references(for commits: [Commit], repository: String) -> String {
    let pullRequestLinks = Set(commits.compactMap(\.pullRequest)).sorted().map {
        "[#\($0)](https://github.com/\(repository)/pull/\($0))"
    }
    let commitLinks = commits.filter { $0.pullRequest == nil }.map {
        "[`\($0.shortSha)`](https://github.com/\(repository)/commit/\($0.sha))"
    }
    let links = pullRequestLinks + commitLinks
    return links.isEmpty ? "" : " (\(links.joined(separator: ", ")))"
}

func markdown(for notes: ReleaseNotes, context: ReleaseContext) -> String {
    let commitsById = Dictionary(uniqueKeysWithValues: context.commits.map { ($0.shortSha, $0) })
    let populatedSections = Section.allCases.filter { !notes.items(in: $0).isEmpty }
    var lines: [String] = []

    if !notes.summary.isEmpty {
        lines += [escaped(notes.summary), ""]
    }
    if populatedSections.isEmpty {
        lines += ["No user-facing changes in this release.", ""]
    }
    for section in populatedSections {
        lines += ["### \(section.title)", ""]
        for item in notes.items(in: section) {
            let cited = item.commits.compactMap { commitsById[$0] }
            lines.append("- \(escaped(item.text))\(references(for: cited, repository: context.repository))")
        }
        lines.append("")
    }
    if let previousTag = context.previousTag {
        lines.append(
            "**Full Changelog**: https://github.com/\(context.repository)/compare/\(previousTag)...\(context.tag)"
        )
    }
    return lines.joined(separator: "\n")
}

let arguments = Array(CommandLine.arguments.dropFirst())
let notesFileIndex = arguments.firstIndex(of: "--notes")
let notesFile = notesFileIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
let positionalArguments = arguments.enumerated()
    .filter { !$0.element.hasPrefix("--") && $0.offset != notesFileIndex.map { $0 + 1 } }
    .map(\.element)

guard let tag = positionalArguments.first, notesFileIndex == nil || notesFile != nil else {
    log(ChangelogError.usage.localizedDescription)
    exit(2)
}

do {
    let previous = try previousTag(before: tag)
    let range = previous.map { "\($0)..\(tag)" } ?? tag
    let context = ReleaseContext(
        repository: try repositorySlug(),
        tag: tag,
        previousTag: previous,
        commits: try userFacingCommits(in: range, pullRequests: try pullRequestNumbers(in: range))
    )
    log("\(context.commits.count) user-facing commits in \(range).")

    var notes = fallbackNotes(for: context.commits)
    let environment = ProcessInfo.processInfo.environment
    if let notesFile {
        guard let data = FileManager.default.contents(atPath: notesFile) else {
            throw ChangelogError.unreadableNotesFile(notesFile)
        }
        notes = try decodeNotes(data, commits: context.commits)
    } else if arguments.contains("--no-ai") || context.commits.isEmpty {
        log("Using the commit headlines as release notes.")
    } else if let apiKey = environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty {
        do {
            notes = try await generatedNotes(
                for: context,
                apiKey: apiKey,
                model: environment["DEEPSEEK_MODEL"] ?? "deepseek-flash"
            )
        } catch {
            warn("\(error.localizedDescription) Falling back to the commit headlines.")
        }
    } else {
        warn("DEEPSEEK_API_KEY is not set. Falling back to the commit headlines.")
    }

    print(markdown(for: notes, context: context))
} catch {
    log("error: \(error.localizedDescription)")
    exit(1)
}
