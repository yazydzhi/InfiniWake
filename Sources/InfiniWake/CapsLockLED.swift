import Foundation
import IOKit.hid

/// Управление лампочкой Caps Lock как индикатором (не как переключателем).
final class CapsLockLED {
    private let kIOHIDCapsLockState: Int32 = 0x00000001

    /// Текущее аппаратное состояние Caps Lock.
    func isOn() -> Bool {
        var state: Bool = false
        let result = IOHIDGetModifierLockState(nil, kIOHIDCapsLockState, &state)
        guard result == kIOReturnSuccess else { return false }
        return state
    }

    /// Включить или выключить LED Caps Lock.
    @discardableResult
    func setOn(_ on: Bool) -> Bool {
        let result = IOHIDSetModifierLockState(nil, kIOHIDCapsLockState, on)
        return result == kIOReturnSuccess
    }
}

// IOHID modifier lock API (не всегда в публичных заголовках Swift)
@_silgen_name("IOHIDGetModifierLockState")
func IOHIDGetModifierLockState(
    _ token: UnsafeMutableRawPointer?,
    _ selector: Int32,
    _ state: UnsafeMutablePointer<Bool>
) -> kern_return_t

@_silgen_name("IOHIDSetModifierLockState")
func IOHIDSetModifierLockState(
    _ token: UnsafeMutableRawPointer?,
    _ selector: Int32,
    _ state: Bool
) -> kern_return_t
