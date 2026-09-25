import Foundation

enum JSONValue: Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(_ any: Any) {
        switch any {
        case let dict as [String: Any]:
            self = .object(dict.mapValues { JSONValue($0) })
        case let arr as [Any]:
            self = .array(arr.map { JSONValue($0) })
        case let s as String:
            self = .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .bool(n.boolValue)
            } else {
                self = .number(n.doubleValue)
            }
        case Optional<Any>.none:
            self = .null
        case is NSNull:
            self = .null
        default:
            self = .null
        }
    }

    subscript(_ key: String) -> JSONValue? {
        if case .object(let obj) = self { return obj[key] }
        return nil
    }

    var string: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var int: Int? {
        if case .number(let n) = self { return Int(n) }
        return nil
    }

    var double: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var bool: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var array: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var object: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}

struct VercelAPIError: Error, LocalizedError, Sendable {
    var status: Int?
    var detail: String

    var errorDescription: String? { detail }

    static func decodeFailed(_ resource: String, _ detail: String) -> VercelAPIError {
        VercelAPIError(status: nil, detail: "Failed to decode \(resource): \(detail)")
    }
}
