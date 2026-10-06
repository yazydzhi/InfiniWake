import Foundation

/// Karabiner по умолчанию забирает Caps Lock LED на VirtualHID и не синхронизирует её
/// с IOHIDSetModifierLockState (InfiniWake/F4). Тогда софт-Caps=ON, а лампа Off.
/// Фикс: manipulate_caps_lock_led=false для встроенной клавиатуры.
enum KarabinerCapsLockLEDFix {
    private static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/karabiner/karabiner.json")
    private static let logURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/InfiniWake", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("led.log")
    }()

    /// Идемпотентно: если Karabiner есть и LED ещё манипулируется — выключаем для built-in.
    @discardableResult
    static func ensureBuiltInKeyboardLEDPassthrough() -> Bool {
        let path = configURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        guard
            let data = try? Data(contentsOf: configURL),
            var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            var profiles = root["profiles"] as? [[String: Any]]
        else {
            log("karabiner.json parse failed")
            return false
        }

        var changed = false
        for index in profiles.indices {
            guard profiles[index]["selected"] as? Bool == true else { continue }
            var devices = profiles[index]["devices"] as? [[String: Any]] ?? []
            var foundBuiltIn = false
            for deviceIndex in devices.indices {
                let identifiers = devices[deviceIndex]["identifiers"] as? [String: Any] ?? [:]
                let isBuiltIn = identifiers["is_built_in_keyboard"] as? Bool == true
                guard isBuiltIn || isLikelyAppleInternalKeyboard(identifiers) else { continue }
                foundBuiltIn = true
                if devices[deviceIndex]["manipulate_caps_lock_led"] as? Bool != false {
                    devices[deviceIndex]["manipulate_caps_lock_led"] = false
                    changed = true
                }
            }
            if !foundBuiltIn {
                devices.append([
                    "identifiers": [
                        "is_keyboard": true,
                        "is_built_in_keyboard": true
                    ],
                    "manipulate_caps_lock_led": false
                ])
                changed = true
            }
            profiles[index]["devices"] = devices
        }

        guard changed else {
            log("karabiner LED passthrough already OK")
            return true
        }

        root["profiles"] = profiles
        guard
            let out = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        else {
            log("karabiner.json serialize failed")
            return false
        }

        let backup = configURL.deletingLastPathComponent()
            .appendingPathComponent("karabiner.json.bak-infiniwake")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: configURL, to: backup)
        do {
            try out.write(to: configURL)
            log("karabiner: set manipulate_caps_lock_led=false for built-in keyboard")
            return true
        } catch {
            log("karabiner.json write failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func isLikelyAppleInternalKeyboard(_ identifiers: [String: Any]) -> Bool {
        guard identifiers["is_keyboard"] as? Bool == true else { return false }
        if identifiers["is_built_in_keyboard"] as? Bool == true { return true }
        let vendor = identifiers["vendor_id"] as? Int
        let product = identifiers["product_id"] as? Int
        return vendor == 0 && product == 0
    }

    private static func log(_ line: String) {
        let text = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }
}
