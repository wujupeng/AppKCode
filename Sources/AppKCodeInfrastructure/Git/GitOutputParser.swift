import Foundation
import AppKCodeShared

public final class GitOutputParser: @unchecked Sendable {
    public init() {}

    public func parseStatus(_ output: String) -> (branch: String?, upstream: String?, ahead: Int, behind: Int, files: [GitFileStatusItem]) {
        var branch: String? = nil
        var upstream: String? = nil
        var ahead = 0
        var behind = 0
        var files: [GitFileStatusItem] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)

            if lineStr.hasPrefix("## ") {
                let branchPart = String(lineStr.dropFirst(3))
                if let ellipsisRange = branchPart.range(of: "...") {
                    branch = String(branchPart[..<ellipsisRange.lowerBound])
                    let upstreamPart = String(branchPart[ellipsisRange.upperBound...])
                    upstream = upstreamPart.split(separator: " ").first.map(String.init) ?? upstreamPart

                    if let aheadRange = upstreamPart.range(of: "ahead ") {
                        let afterAhead = String(upstreamPart[aheadRange.upperBound...])
                        ahead = Int(afterAhead.split(separator: " ").first ?? "") ?? 0
                    }
                    if let behindRange = upstreamPart.range(of: "behind ") {
                        let afterBehind = String(upstreamPart[behindRange.upperBound...])
                        behind = Int(afterBehind.split(separator: " ").first ?? "") ?? 0
                    }
                } else {
                    branch = branchPart
                }
                continue
            }

            guard lineStr.count >= 2 else { continue }
            let x = lineStr[lineStr.startIndex]
            let y = lineStr[lineStr.index(after: lineStr.startIndex)]
            let pathStart = lineStr.index(lineStr.startIndex, offsetBy: 3)

            if x == "?" && y == "?" {
                let path = String(lineStr[pathStart...])
                files.append(GitFileStatusItem(path: path, status: .untracked, staged: false))
            } else if x == "A" || x == "M" || x == "D" || x == "R" || x == "C" {
                let pathStr = String(lineStr[pathStart...])
                if x == "R" {
                    let parts = pathStr.split(separator: " -> ")
                    if parts.count == 2 {
                        files.append(GitFileStatusItem(path: String(parts[1]), status: .renamed, staged: true, oldPath: String(parts[0])))
                    } else {
                        files.append(GitFileStatusItem(path: pathStr, status: .staged, staged: true))
                    }
                } else {
                    let status: GitFileStatus = x == "D" ? .deleted : .staged
                    files.append(GitFileStatusItem(path: pathStr, status: status, staged: true))
                }
            } else if y == "M" {
                let path = String(lineStr[pathStart...])
                files.append(GitFileStatusItem(path: path, status: .modified, staged: false))
            } else if y == "D" {
                let path = String(lineStr[pathStart...])
                files.append(GitFileStatusItem(path: path, status: .deleted, staged: false))
            } else if x == " " && y != " " {
                let path = String(lineStr[pathStart...])
                let status: GitFileStatus = y == "D" ? .deleted : .modified
                files.append(GitFileStatusItem(path: path, status: status, staged: false))
            } else if x == "U" || y == "U" {
                let path = String(lineStr[pathStart...])
                files.append(GitFileStatusItem(path: path, status: .conflicted, staged: false))
            }
        }

        return (branch, upstream, ahead, behind, files)
    }

    public func parseDiff(_ output: String) -> [GitFileDiff] {
        var fileDiffs: [GitFileDiff] = []
        var currentOldPath = ""
        var currentNewPath = ""
        var currentHunks: [GitDiffHunk] = []
        var currentHunkLines: [GitDiffLine] = []
        var currentOldStart = 0
        var currentOldCount = 0
        var currentNewStart = 0
        var currentNewCount = 0
        var addedCount = 0
        var deletedCount = 0
        var oldLineNum = 0
        var newLineNum = 0

        func finalizeHunk() {
            if !currentHunkLines.isEmpty {
                currentHunks.append(GitDiffHunk(
                    oldStartLine: currentOldStart, oldLineCount: currentOldCount,
                    newStartLine: currentNewStart, newLineCount: currentNewCount,
                    lines: currentHunkLines
                ))
                currentHunkLines = []
            }
        }

        func finalizeFile() {
            finalizeHunk()
            if !currentOldPath.isEmpty || !currentNewPath.isEmpty {
                fileDiffs.append(GitFileDiff(
                    oldPath: currentOldPath, newPath: currentNewPath,
                    hunks: currentHunks, addedLinesCount: addedCount, deletedLinesCount: deletedCount
                ))
            }
            currentHunks = []
            addedCount = 0
            deletedCount = 0
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)

            if lineStr.hasPrefix("diff --git") {
                finalizeFile()
                currentOldPath = ""
                currentNewPath = ""
                continue
            }

            if lineStr.hasPrefix("--- ") {
                let path = String(lineStr.dropFirst(4))
                currentOldPath = path == "/dev/null" ? "" : path
                continue
            }

            if lineStr.hasPrefix("+++ ") {
                let path = String(lineStr.dropFirst(4))
                currentNewPath = path == "/dev/null" ? "" : path
                continue
            }

            if lineStr.hasPrefix("@@ ") {
                finalizeHunk()
                let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(lineStr.startIndex..., in: lineStr)
                    if let match = regex.firstMatch(in: lineStr, range: range) {
                        if let r = Range(match.range(at: 1), in: lineStr) { currentOldStart = Int(lineStr[r]) ?? 0 }
                        if let r = Range(match.range(at: 2), in: lineStr) { currentOldCount = Int(lineStr[r]) ?? 1 }
                        else { currentOldCount = 1 }
                        if let r = Range(match.range(at: 3), in: lineStr) { currentNewStart = Int(lineStr[r]) ?? 0 }
                        if let r = Range(match.range(at: 4), in: lineStr) { currentNewCount = Int(lineStr[r]) ?? 1 }
                        else { currentNewCount = 1 }
                    }
                }
                oldLineNum = currentOldStart
                newLineNum = currentNewStart
                continue
            }

            if lineStr.hasPrefix("+") && !lineStr.hasPrefix("+++") {
                currentHunkLines.append(GitDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: newLineNum, content: String(lineStr.dropFirst())))
                newLineNum += 1
                addedCount += 1
            } else if lineStr.hasPrefix("-") && !lineStr.hasPrefix("---") {
                currentHunkLines.append(GitDiffLine(kind: .deleted, oldLineNumber: oldLineNum, newLineNumber: nil, content: String(lineStr.dropFirst())))
                oldLineNum += 1
                deletedCount += 1
            } else if lineStr.hasPrefix(" ") {
                currentHunkLines.append(GitDiffLine(kind: .context, oldLineNumber: oldLineNum, newLineNumber: newLineNum, content: String(lineStr.dropFirst())))
                oldLineNum += 1
                newLineNum += 1
            }
        }

        finalizeFile()
        return fileDiffs
    }

    public func parseLog(_ output: String) -> [GitCommitInfo] {
        var commits: [GitCommitInfo] = []
        let separator = "\u{1F}" // Record separator
        let fieldSeparator = "\u{1E}" // Field separator

        for record in output.split(separator: Character(separator)) {
            let fields = String(record).split(separator: Character(fieldSeparator), omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 10 else { continue }

            let sha = fields[0]
            let shortSha = String(sha.prefix(7))
            let authorName = fields[1]
            let authorEmail = fields[2]
            let authorDate = parseGitDate(fields[3])
            let committerName = fields[4]
            let committerEmail = fields[5]
            let committerDate = parseGitDate(fields[6])
            let messageSubject = fields[7]
            let messageBody = fields[8]
            let message = messageBody.isEmpty ? messageSubject : "\(messageSubject)\n\(messageBody)"
            let parents = fields[9].split(separator: " ").map(String.init)

            commits.append(GitCommitInfo(
                sha: sha, shortSha: shortSha,
                authorName: authorName, authorEmail: authorEmail, authorDate: authorDate,
                committerName: committerName, committerEmail: committerEmail, committerDate: committerDate,
                message: message, messageSubject: messageSubject, messageBody: messageBody,
                parentShas: parents
            ))
        }

        return commits
    }

    public func parseBranches(_ output: String) -> [GitBranchInfo] {
        var branches: [GitBranchInfo] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            guard lineStr.count >= 3 else { continue }

            let isCurrent = lineStr.hasPrefix("*")
            let isRemote = lineStr.contains("remotes/")
            let refStart = lineStr.index(lineStr.startIndex, offsetBy: 2)
            let refEnd = lineStr.endIndex

            var name = String(lineStr[refStart..<refEnd]).trimmingCharacters(in: .whitespaces)
            if let spaceRange = name.range(of: " ") {
                name = String(name[..<spaceRange.lowerBound])
            }

            branches.append(GitBranchInfo(
                name: name, isCurrent: isCurrent, isRemote: isRemote,
                upstreamTracking: nil, lastCommitSha: "", lastCommitDate: Date()
            ))
        }

        return branches
    }

    private func parseGitDate(_ s: String) -> Date {
        if let timestamp = TimeInterval(s) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return Date()
    }

    public var logFormat: String {
        let sep = "\u{1E}"
        let recordSep = "\u{1F}"
        return "%H\(sep)%an\(sep)%ae\(sep)%at\(sep)%cn\(sep)%ce\(sep)%ct\(sep)%s\(sep)%b\(sep)%P\(recordSep)"
    }
}