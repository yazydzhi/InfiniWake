import AppKit
import Carbon.HIToolbox

/// Глобальный хоткей без зависимости от Caps Lock.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onToggle: (() -> Void)?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x49574B48), id: 1) // 'KLTK'

    deinit {
        unregister()
    }

    func register(keyCode: UInt16, modifiers: UInt32) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if status == noErr, hkID.id == manager.hotKeyID.id {
                DispatchQueue.main.async {
                    manager.onToggle?()
                }
            }
            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &handler
        )
        guard installStatus == noErr else { return }
        eventHandler = handler

        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if registerStatus == noErr {
            hotKeyRef = ref
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Человекочитаемое имя клавиши для меню.
    static func displayName(keyCode: UInt16, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_Space: return "Space"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        default: return "Key\(keyCode)"
        }
    }
}
