//    From  https://github.com/iwill/generic-json-swift/
//
//    MIT License
//
//    Copyright (c) 2017 Tomáš Znamenáček
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

import Foundation

/// A JSON value representation. This is a bit more useful than the naïve `[String:Any]` type
/// for JSON values, since it makes sure only valid JSON values are present & supports `Equatable`
/// and `Codable`, so that you can compare values for equality and code and decode them into data
/// or strings.
///
/// From  https://github.com/iwill/generic-json-swift/
@dynamicMemberLookup
public enum JSON: Codable, Hashable {
    case string(String)
    case number(Double)
    case object([String:JSON])
    case array([JSON])
    case bool(Bool)
    case null

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let object = try? container.decode([String: JSON].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSON].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
            )
        }
    }

    public var debugDescription: String {
        switch self {
        case .string(let str):
            return str.debugDescription
        case .number(let num):
            return num.debugDescription
        case .bool(let bool):
            return bool.description
        case .null:
            return "null"
        default:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return try! String(data: encoder.encode(self), encoding: .utf8)!
        }
    }

    /// If this is an `.array`, return item at index
    ///
    /// If this is not an `.array` or the index is out of bounds, returns `nil`.
    public subscript(index: Int) -> JSON? {
        if case .array(let arr) = self, arr.indices.contains(index) {
            return arr[index]
        }
        return nil
    }

    /// If this is an `.object`, return item at key
    public subscript(key: String) -> JSON? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }

    /// Dynamic member lookup sugar for string subscripts
    ///
    /// This lets you write `json.foo` instead of `json["foo"]`.
    public subscript(dynamicMember member: String) -> JSON? {
        self[member]
    }

    /// Return the JSON type at the keypath if this is an `.object`, otherwise `nil`
    ///
    /// This lets you write `json[keyPath: "foo.bar.jar"]`.
    public subscript(keyPath keyPath: String) -> JSON? {
        queryKeyPath(keyPath.components(separatedBy: "."))
    }

    func queryKeyPath<T>(_ path: T) -> JSON? where T: Collection, T.Element == String {

        // Only object values may be subscripted
        guard case .object(let object) = self else {
            return nil
        }

        // Is the path non-empty?
        guard let head = path.first else {
            return nil
        }

        // Do we have a value at the required key?
        guard let value = object[head] else {
            return nil
        }

        let tail = path.dropFirst()

        return tail.isEmpty ? value : value.queryKeyPath(tail)
    }

}

private struct InitializationError: Error {}

extension JSON {

    /// Create a JSON value from anything.
    ///
    /// Argument has to be a valid JSON structure: A `Double`, `Int`, `String`,
    /// `Bool`, an `Array` of those types or a `Dictionary` of those types.
    ///
    /// You can also pass `nil` or `NSNull`, both will be treated as `.null`.
    public init(_ value: Any) throws {
        switch value {
        case _ as NSNull:
            self = .null
        case let opt as Optional<Any> where opt == nil:
            self = .null
        case let num as NSNumber:
            if num.isBool {
                self = .bool(num.boolValue)
            } else {
                self = .number(num.doubleValue)
            }
        case let str as String:
            self = .string(str)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = try .array(array.map(JSON.init))
        case let dict as [String:Any]:
            self = try .object(dict.mapValues(JSON.init))
        default:
            throw InitializationError()
        }
    }
}

extension JSON {

    /// Create a JSON value from an `Encodable`. This will give you access to the “raw”
    /// encoded JSON value the `Encodable` is serialized into.
    public init<T: Encodable>(encodable: T) throws {
        let encoded = try JSONEncoder().encode(encodable)
        self = try JSONDecoder().decode(JSON.self, from: encoded)
    }
}

extension JSON: ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSON: ExpressibleByNilLiteral {

    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSON: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: JSON...) {
        self = .array(elements)
    }
}

extension JSON: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, JSON)...) {
        var object: [String:JSON] = [:]
        for (k, v) in elements {
            object[k] = v
        }
        self = .object(object)
    }
}

extension JSON: ExpressibleByFloatLiteral {

    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSON: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSON: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

// MARK: - NSNumber

extension NSNumber {

    /// Boolean value indicating whether this `NSNumber` wraps a boolean.
    ///
    /// For example, when using `NSJSONSerialization` Bool values are converted into `NSNumber` instances.
    ///
    /// - seealso: https://stackoverflow.com/a/49641315/3589408
    fileprivate var isBool: Bool {
        let objCType = String(cString: objCType)
        if
            (compare(trueNumber) == .orderedSame && objCType == trueObjCType) ||
            (compare(falseNumber) == .orderedSame && objCType == falseObjCType)
        {
            return true
        } else {
            return false
        }
    }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)
