import Foundation


public enum DiffEngine {
    public static func computeDiff(old: String, new: String) -> [DiffHunk] {
        let oldLines = Array(old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        let newLines = Array(new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        return computeDiff(oldLines: oldLines, newLines: newLines)
    }

    public static func computeDiff(oldLines: [String], newLines: [String]) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var oldIdx = 0
        var newIdx = 0

        while oldIdx < oldLines.count || newIdx < newLines.count {
            var diffLines: [DiffLine] = []
            let hunkOldStart = oldIdx
            let hunkNewStart = newIdx

            while oldIdx < oldLines.count && newIdx < newLines.count && oldLines[oldIdx] == newLines[newIdx] {
                oldIdx += 1
                newIdx += 1
            }

            let changeStartOld = oldIdx
            let changeStartNew = newIdx

            while oldIdx < oldLines.count && newIdx < newLines.count && oldLines[oldIdx] != newLines[newIdx] {
                let lcsLen = lcsLength(oldLines[oldIdx...], newLines[newIdx...])
                if lcsLen == 0 {
                    if oldIdx < oldLines.count {
                        diffLines.append(DiffLine(content: oldLines[oldIdx], changeType: .removed))
                        oldIdx += 1
                    }
                    if newIdx < newLines.count {
                        diffLines.append(DiffLine(content: newLines[newIdx], changeType: .added))
                        newIdx += 1
                    }
                } else {
                    break
                }
            }

            while oldIdx < oldLines.count && (newIdx >= newLines.count || oldLines[oldIdx] != newLines[newIdx]) {
                diffLines.append(DiffLine(content: oldLines[oldIdx], changeType: .removed))
                oldIdx += 1
            }

            while newIdx < newLines.count && (oldIdx >= oldLines.count || oldLines[oldIdx] != newLines[newIdx]) {
                diffLines.append(DiffLine(content: newLines[newIdx], changeType: .added))
                newIdx += 1
            }

            if !diffLines.isEmpty {
                hunks.append(DiffHunk(
                    oldStart: changeStartOld + 1,
                    oldEnd: oldIdx,
                    newStart: changeStartNew + 1,
                    newEnd: newIdx,
                    lines: diffLines
                ))
            }
        }

        return hunks
    }

    public static func applyHunks(_ hunks: [DiffHunk], to original: String, acceptedHunkIndices: Set<Int>) -> String {
        var lines = Array(original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        var offset = 0

        for (idx, hunk) in hunks.enumerated() where acceptedHunkIndices.contains(idx) {
            let insertStart = hunk.oldStart - 1 + offset
            let removeCount = hunk.oldEnd - hunk.oldStart + 1
            let addedLines = hunk.lines.filter { $0.changeType == .added }.map { $0.content }

            lines.removeSubrange(insertStart..<min(insertStart + removeCount, lines.count))
            lines.insert(contentsOf: addedLines, at: insertStart)
            offset += addedLines.count - removeCount
        }

        return lines.joined(separator: "\n")
    }

    private static func lcsLength(_ a: ArraySlice<String>, _ b: ArraySlice<String>) -> Int {
        let aArray = Array(a)
        let bArray = Array(b)
        if aArray.isEmpty || bArray.isEmpty { return 0 }
        var dp = Array(repeating: Array(repeating: 0, count: bArray.count + 1), count: aArray.count + 1)
        for i in 1...aArray.count {
            for j in 1...bArray.count {
                if aArray[i-1] == bArray[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        return dp[aArray.count][bArray.count]
    }
}