// PlistIO.swift
// MunkiOnboarding

import Foundation

enum PlistIOError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): "File not found: \(p)"
        case .invalidFormat(let p): "Invalid plist format: \(p)"
        case .writeFailed(let p): "Write failed: \(p)"
        }
    }
}

enum PlistIO {
    static func read(_ path: String) throws -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw PlistIOError.fileNotFound(path)
        }
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        let obj = try PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainers,
            format: &fmt
        )
        guard let dict = obj as? [String: Any] else {
            throw PlistIOError.invalidFormat(path)
        }
        return dict
    }

    static func write(_ dict: [String: Any], to path: String) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
        guard (data as NSData).write(toFile: path, atomically: true) else {
            throw PlistIOError.writeFailed(path)
        }
    }
}
