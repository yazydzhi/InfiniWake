import Carbon.HIToolbox

/// Вариант хоткея в настройках.
struct HotKeyOption: Equatable {
    let title: String
    let keyCode: UInt16
    let modifiers: UInt32

    /// Caps Lock нельзя повесить через RegisterEventHotKey — отдельный режим.
    var isCapsLock: Bool {
        Int(keyCode) == kVK_CapsLock && modifiers == 0
    }

    static let all: [HotKeyOption] = {
        var items: [HotKeyOption] = [
            HotKeyOption(title: "Caps Lock", keyCode: UInt16(kVK_CapsLock), modifiers: 0)
        ]

        let functionKeys: [(String, Int)] = [
            ("F1", kVK_F1), ("F2", kVK_F2), ("F3", kVK_F3), ("F4", kVK_F4),
            ("F5", kVK_F5), ("F6", kVK_F6), ("F7", kVK_F7), ("F8", kVK_F8),
            ("F9", kVK_F9), ("F10", kVK_F10), ("F11", kVK_F11), ("F12", kVK_F12)
        ]
        for (title, code) in functionKeys {
            items.append(HotKeyOption(title: title, keyCode: UInt16(code), modifiers: 0))
        }

        let modifiedFunction: [(String, Int, Int)] = [
            ("⌃F4", kVK_F4, controlKey),
            ("⌥F4", kVK_F4, optionKey),
            ("⌘F4", kVK_F4, cmdKey),
            ("⌃F5", kVK_F5, controlKey),
            ("⌥F5", kVK_F5, optionKey),
            ("⌃F6", kVK_F6, controlKey),
            ("⌥F6", kVK_F6, optionKey),
            ("⌃F8", kVK_F8, controlKey),
            ("⌥F8", kVK_F8, optionKey)
        ]
        for (title, code, mods) in modifiedFunction {
            items.append(HotKeyOption(title: title, keyCode: UInt16(code), modifiers: UInt32(mods)))
        }

        let combos: [(String, Int, Int)] = [
            ("⌘⇧L", kVK_ANSI_L, cmdKey | shiftKey),
            ("⌘⇧K", kVK_ANSI_K, cmdKey | shiftKey),
            ("⌘⇧W", kVK_ANSI_W, cmdKey | shiftKey),
            ("⌃⌥W", kVK_ANSI_W, controlKey | optionKey),
            ("⌃⌥L", kVK_ANSI_L, controlKey | optionKey),
            ("⌃Space", kVK_Space, controlKey),
            ("⌥Space", kVK_Space, optionKey),
            ("⌘Esc", kVK_Escape, cmdKey),
            ("⌃⇧P", kVK_ANSI_P, controlKey | shiftKey)
        ]
        for (title, code, mods) in combos {
            items.append(HotKeyOption(title: title, keyCode: UInt16(code), modifiers: UInt32(mods)))
        }

        return items
    }()

    static func matching(keyCode: UInt16, modifiers: UInt32) -> HotKeyOption? {
        all.first { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }
}
