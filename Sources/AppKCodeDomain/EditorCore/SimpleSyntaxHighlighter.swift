import Foundation
import AppKCodeShared

public final class SimpleSyntaxHighlighter: DomainSyntaxHighlighter {
    public let language: String
    private let keywords: Set<String>
    private let lineCommentPrefix: String?
    private let blockCommentStart: String?
    private let blockCommentEnd: String?
    private let stringDelimiters: [(String, String)]

    public init(language: String, keywords: Set<String> = [],
                lineCommentPrefix: String? = nil,
                blockCommentStart: String? = nil, blockCommentEnd: String? = nil,
                stringDelimiters: [(String, String)] = [("\"", "\""), ("'", "'")]) {
        self.language = language
        self.keywords = keywords
        self.lineCommentPrefix = lineCommentPrefix
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.stringDelimiters = stringDelimiters
    }

    public func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var i = text.startIndex
        var offset = 0

        while i < text.endIndex {
            if let prefix = lineCommentPrefix, text[i...].hasPrefix(prefix) {
                var lineEnd = i
                while lineEnd < text.endIndex && text[lineEnd] != "\n" {
                    lineEnd = text.index(after: lineEnd)
                }
                let length = text.distance(from: i, to: lineEnd)
                tokens.append(SyntaxToken(type: .comment,
                    range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                      end: TextLocation(line: 0, column: 0, offset: offset + length)),
                    text: String(text[i..<lineEnd])))
                offset += length
                i = lineEnd
                continue
            }

            if let start = blockCommentStart, let end = blockCommentEnd, text[i...].hasPrefix(start) {
                if let endRange = text.range(of: end, range: i..<text.endIndex) {
                    let length = text.distance(from: i, to: endRange.upperBound)
                    tokens.append(SyntaxToken(type: .comment,
                        range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                          end: TextLocation(line: 0, column: 0, offset: offset + length)),
                        text: String(text[i..<endRange.upperBound])))
                    offset += length
                    i = endRange.upperBound
                    continue
                }
            }

            var matchedString = false
            for (open, close) in stringDelimiters {
                if String(text[i]).hasPrefix(open) {
                    var j = text.index(after: i)
                    while j < text.endIndex {
                        if String(text[j]).hasPrefix(close) {
                            let length = text.distance(from: i, to: text.index(after: j))
                            tokens.append(SyntaxToken(type: .string,
                                range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                                  end: TextLocation(line: 0, column: 0, offset: offset + length)),
                                text: String(text[i...j])))
                            offset += length
                            i = text.index(after: j)
                            matchedString = true
                            break
                        }
                        j = text.index(after: j)
                    }
                    if matchedString { break }
                }
            }
            if matchedString { continue }

            let ch = text[i]
            if ch.isLetter || ch == "_" {
                var j = i
                while j < text.endIndex && (text[j].isLetter || text[j].isNumber || text[j] == "_") {
                    j = text.index(after: j)
                }
                let word = String(text[i..<j])
                let length = word.count
                let tokenType: SyntaxTokenType
                if keywords.contains(word) {
                    tokenType = .keyword
                } else if word.first?.isUppercase == true {
                    tokenType = .type
                } else {
                    tokenType = .identifier
                }
                tokens.append(SyntaxToken(type: tokenType,
                    range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                      end: TextLocation(line: 0, column: 0, offset: offset + length)),
                    text: word))
                offset += length
                i = j
                continue
            }

            if ch.isNumber {
                var j = i
                while j < text.endIndex && (text[j].isNumber || text[j] == ".") {
                    j = text.index(after: j)
                }
                let length = text.distance(from: i, to: j)
                tokens.append(SyntaxToken(type: .number,
                    range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                      end: TextLocation(line: 0, column: 0, offset: offset + length)),
                    text: String(text[i..<j])))
                offset += length
                i = j
                continue
            }

            let length = 1
            tokens.append(SyntaxToken(type: .plain,
                range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                  end: TextLocation(line: 0, column: 0, offset: offset + length)),
                text: String(ch)))
            offset += length
            i = text.index(after: i)
        }
        return tokens
    }
}

public final class SyntaxHighlighterRegistry: @unchecked Sendable {
    private var highlighters: [String: DomainSyntaxHighlighter] = [:]
    private let lock = NSLock()

    public init() {
        registerDefaults()
    }

    public func register(_ highlighter: DomainSyntaxHighlighter) {
        lock.lock(); defer { lock.unlock() }
        highlighters[highlighter.language] = highlighter
    }

    public func highlighter(for language: String) -> DomainSyntaxHighlighter? {
        lock.lock(); defer { lock.unlock() }
        return highlighters[language]
    }

    private func registerDefaults() {
        register(SimpleSyntaxHighlighter(language: "Swift", keywords: swiftKeywords, lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "Objective-C", keywords: cKeywords.union(objcKeywords), lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "C", keywords: cKeywords, lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "C++", keywords: cKeywords.union(cppKeywords), lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "Python", keywords: pythonKeywords, lineCommentPrefix: "#", blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: [("\"", "\""), ("'", "'"), ("\"\"\"", "\"\"\"")]))
        register(SimpleSyntaxHighlighter(language: "Go", keywords: goKeywords, lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "JavaScript", keywords: jsKeywords, lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "TypeScript", keywords: jsKeywords.union(tsKeywords), lineCommentPrefix: "//", blockCommentStart: "/*", blockCommentEnd: "*/"))
        register(SimpleSyntaxHighlighter(language: "JSON", keywords: [], lineCommentPrefix: nil, blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: [("\"", "\"")]))
        register(SimpleSyntaxHighlighter(language: "YAML", keywords: [], lineCommentPrefix: "#", blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: [("\"", "\""), ("'", "'")]))
        register(SimpleSyntaxHighlighter(language: "Markdown", keywords: [], lineCommentPrefix: nil, blockCommentStart: nil, blockCommentEnd: nil, stringDelimiters: [("`", "`")]))
    }

    private let swiftKeywords: Set<String> = ["func", "var", "let", "class", "struct", "enum", "protocol", "extension", "import", "public", "private", "internal", "fileprivate", "static", "if", "else", "guard", "for", "while", "switch", "case", "default", "break", "continue", "return", "throw", "throws", "try", "catch", "do", "defer", "in", "where", "as", "is", "nil", "true", "false", "self", "super", "init", "deinit", "subscript", "operator", "infix", "prefix", "postfix", "mutating", "nonmutating", "override", "convenience", "required", "optional", "weak", "unowned", "lazy", "final", "open", "indirect", "associatedtype", "typealias", "some", "any", "async", "await", "actor", "Sendable", "unchecked"]

    private let cKeywords: Set<String> = ["int", "char", "float", "double", "void", "long", "short", "unsigned", "signed", "const", "static", "extern", "register", "volatile", "auto", "if", "else", "while", "for", "do", "switch", "case", "default", "break", "continue", "return", "goto", "sizeof", "struct", "union", "enum", "typedef", "#include", "#define", "#ifdef", "#ifndef", "#endif", "#if", "#else", "#elif", "#pragma"]

    private let objcKeywords: Set<String> = ["@interface", "@implementation", "@end", "@property", "@synthesize", "@dynamic", "@class", "@protocol", "@optional", "@required", "@selector", "@encode", "@defs", "id", "YES", "NO", "nil", "Nil", "self", "super", "instancetype", "nonatomic", "atomic", "strong", "weak", "copy", "retain", "assign", "readonly", "readwrite"]

    private let cppKeywords: Set<String> = ["namespace", "using", "template", "typename", "class", "public", "private", "protected", "virtual", "override", "final", "new", "delete", "this", "nullptr", "true", "false", "std", "const", "constexpr", "auto", "static_cast", "dynamic_cast", "reinterpret_cast", "const_cast", "noexcept", "throw", "try", "catch", "operator", "friend", "inline", "explicit", "mutable", "thread_local"]

    private let pythonKeywords: Set<String> = ["def", "class", "if", "elif", "else", "while", "for", "in", "not", "and", "or", "is", "None", "True", "False", "import", "from", "as", "pass", "break", "continue", "return", "yield", "raise", "try", "except", "finally", "with", "lambda", "global", "nonlocal", "del", "assert", "async", "await", "self", "cls", "print", "len", "range", "str", "int", "float", "list", "dict", "set", "tuple", "bool"]

    private let goKeywords: Set<String> = ["func", "var", "const", "type", "struct", "interface", "package", "import", "if", "else", "for", "range", "switch", "case", "default", "break", "continue", "return", "go", "defer", "select", "chan", "map", "nil", "true", "false", "make", "new", "len", "cap", "append", "copy", "delete", "close", "panic", "recover", "print", "println", "iota"]

    private let jsKeywords: Set<String> = ["function", "var", "let", "const", "class", "extends", "super", "this", "new", "delete", "typeof", "instanceof", "void", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "throw", "try", "catch", "finally", "import", "export", "from", "as", "async", "await", "yield", "true", "false", "null", "undefined", "NaN", "Infinity", "console", "require", "module"]

    private let tsKeywords: Set<String> = ["type", "interface", "enum", "namespace", "declare", "readonly", "public", "private", "protected", "static", "abstract", "implements", "keyof", "typeof", "infer", "is", "as", "satisfies", "never", "unknown", "any", "string", "number", "boolean", "symbol", "bigint", "object", "void"]
}