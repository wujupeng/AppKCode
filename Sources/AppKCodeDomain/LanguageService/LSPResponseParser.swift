import Foundation
import AppKCodeInfrastructure

public enum LSPResponseParser {
    public static func parseCompletionItems(_ data: AnyCodable?) -> [CompletionItem] {
        guard let data = data else { return [] }
        var items: [CompletionItem] = []

        if let array = data.value as? [AnyCodable] {
            for item in array {
                if let parsed = parseCompletionItem(item) {
                    items.append(parsed)
                }
            }
        } else if let item = parseCompletionItem(data) {
            items.append(item)
        }

        return items
    }

    private static func parseCompletionItem(_ data: AnyCodable) -> CompletionItem? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        let label = (dict["label"]?.value as? String) ?? ""
        let kind = (dict["kind"]?.value as? Int64).flatMap { CompletionItemKind(rawValue: Int($0)) }
        let detail = dict["detail"]?.value as? String
        let documentation = parseDocumentation(dict["documentation"])
        let insertText = dict["insertText"]?.value as? String
        let sortText = dict["sortText"]?.value as? String
        return CompletionItem(label: label, kind: kind, detail: detail,
                              documentation: documentation, insertText: insertText, sortText: sortText)
    }

    private static func parseDocumentation(_ data: AnyCodable?) -> String? {
        guard let data = data else { return nil }
        if let str = data.value as? String { return str }
        if let dict = data.value as? [String: AnyCodable] {
            return dict["value"]?.value as? String
        }
        return nil
    }

    public static func parseHover(_ data: AnyCodable?) -> HoverInfo? {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else { return nil }
        let contents = parseMarkupContent(dict["contents"])
        let range = parseRange(dict["range"])
        return HoverInfo(contents: contents, range: range)
    }

    private static func parseMarkupContent(_ data: AnyCodable?) -> String {
        guard let data = data else { return "" }
        if let str = data.value as? String { return str }
        if let dict = data.value as? [String: AnyCodable] {
            return (dict["value"]?.value as? String) ?? ""
        }
        return ""
    }

    public static func parseLocations(_ data: AnyCodable?) -> [LSPLocation] {
        guard let data = data else { return [] }
        var locations: [LSPLocation] = []

        if let array = data.value as? [AnyCodable] {
            for item in array {
                if let loc = parseLocation(item) {
                    locations.append(loc)
                }
            }
        } else if let loc = parseLocation(data) {
            locations.append(loc)
        }

        return locations
    }

    private static func parseLocation(_ data: AnyCodable) -> LSPLocation? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        guard let uri = dict["uri"]?.value as? String else { return nil }
        guard let range = parseRange(dict["range"]) else { return nil }
        return LSPLocation(uri: uri, range: range)
    }

    private static func parseRange(_ data: AnyCodable?) -> LSPRange? {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else { return nil }
        guard let start = parsePosition(dict["start"]),
              let end = parsePosition(dict["end"]) else { return nil }
        return LSPRange(start: start, end: end)
    }

    private static func parsePosition(_ data: AnyCodable?) -> LSPPosition? {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else { return nil }
        let line = Int((dict["line"]?.value as? Int64) ?? 0)
        let character = Int((dict["character"]?.value as? Int64) ?? 0)
        return LSPPosition(line: line, character: character)
    }

    public static func parseDiagnostics(_ data: AnyCodable?) -> [Diagnostic] {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else { return [] }
        guard let diagnosticsArray = dict["diagnostics"]?.value as? [AnyCodable] else { return [] }
        var diagnostics: [Diagnostic] = []
        for item in diagnosticsArray {
            if let diag = parseDiagnostic(item) {
                diagnostics.append(diag)
            }
        }
        return diagnostics
    }

    private static func parseDiagnostic(_ data: AnyCodable) -> Diagnostic? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        guard let range = parseRange(dict["range"]) else { return nil }
        let severity = (dict["severity"]?.value as? Int64).flatMap { DiagnosticSeverity(rawValue: Int($0)) } ?? .error
        let code: String?
        if let codeVal = dict["code"]?.value {
            code = "\(codeVal)"
        } else {
            code = nil
        }
        let source = dict["source"]?.value as? String
        let message = (dict["message"]?.value as? String) ?? ""
        return Diagnostic(range: range, severity: severity, code: code, source: source, message: message)
    }

    public static func parseSymbols(_ data: AnyCodable?) -> [SymbolInformation] {
        guard let data = data, let array = data.value as? [AnyCodable] else { return [] }
        var symbols: [SymbolInformation] = []
        for item in array {
            if let symbol = parseSymbol(item) {
                symbols.append(symbol)
            }
        }
        return symbols
    }

    private static func parseSymbol(_ data: AnyCodable) -> SymbolInformation? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        let name = (dict["name"]?.value as? String) ?? ""
        let kind = (dict["kind"]?.value as? Int64).flatMap { SymbolKind(rawValue: Int($0)) } ?? .variable
        guard let location = parseLocation(dict["location"]) else { return nil }
        let containerName = dict["containerName"]?.value as? String
        return SymbolInformation(name: name, kind: kind, location: location, containerName: containerName)
    }

    public static func parseSignatureHelp(_ data: AnyCodable?) -> SignatureHelp? {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else { return nil }
        guard let sigsArray = dict["signatures"]?.value as? [AnyCodable] else { return nil }
        let signatures = sigsArray.compactMap { parseSignatureInformation($0) }
        let activeSignature = (dict["activeSignature"]?.value as? Int64).map { Int($0) }
        let activeParameter = (dict["activeParameter"]?.value as? Int64).map { Int($0) }
        return SignatureHelp(signatures: signatures, activeSignature: activeSignature, activeParameter: activeParameter)
    }

    private static func parseSignatureInformation(_ data: AnyCodable) -> SignatureInformation? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        let label = (dict["label"]?.value as? String) ?? ""
        let documentation = parseDocumentation(dict["documentation"])
        let params = (dict["parameters"]?.value as? [AnyCodable] ?? []).compactMap { parseParameterInformation($0) }
        return SignatureInformation(label: label, documentation: documentation, parameters: params)
    }

    private static func parseParameterInformation(_ data: AnyCodable) -> ParameterInformation? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        let label: String
        if let str = dict["label"]?.value as? String {
            label = str
        } else {
            label = ""
        }
        let documentation = parseDocumentation(dict["documentation"])
        return ParameterInformation(label: label, documentation: documentation)
    }

    public static func parseWorkspaceEdit(_ data: AnyCodable?) -> LSPWorkspaceEdit {
        guard let data = data, let dict = data.value as? [String: AnyCodable] else {
            return LSPWorkspaceEdit()
        }
        guard let changesDict = dict["changes"]?.value as? [String: AnyCodable] else {
            return LSPWorkspaceEdit()
        }
        var changes: [String: [LSPTextEdit]] = [:]
        for (uri, editsData) in changesDict {
            guard let editsArray = editsData.value as? [AnyCodable] else { continue }
            let edits = editsArray.compactMap { parseTextEdit($0) }
            if !edits.isEmpty {
                changes[uri] = edits
            }
        }
        return LSPWorkspaceEdit(changes: changes)
    }

    private static func parseTextEdit(_ data: AnyCodable) -> LSPTextEdit? {
        guard let dict = data.value as? [String: AnyCodable] else { return nil }
        guard let range = parseRange(dict["range"]) else { return nil }
        let newText = (dict["newText"]?.value as? String) ?? ""
        return LSPTextEdit(range: range, newText: newText)
    }
}