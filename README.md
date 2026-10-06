# InfiniWake

**Free · MIT License** · macOS menu-bar keep-awake utility

**Version 1.0.0** · Author: **Vladimir Yazydzhi** (Владимир Языджи)

InfiniWake keeps your Mac awake with a dedicated hotkey (default **F4**).  
Caps Lock is used only as a **physical LED indicator** — not as the toggle — so it stays free for input-source switching. While the LED is on, real CAPS typing is filtered out (Accessibility required).

## Why not Capsomnia?

Capsomnia ties keep-awake to Caps Lock. If you already use Caps Lock for languages, it conflicts.

| | Capsomnia | InfiniWake |
|---|---|---|
| Toggle | Caps Lock (or shortcut still coupled to Caps Lock state) | Hotkey (**F4**) or menu-bar click |
| Caps Lock LED | Mode status | Indicator only; languages keep working |
| Menu-bar icon | Dot | **∞** when unlimited; countdown when timed; dimmed when off |
| Focus | Many settings | Sleep on/off + status |

## Install / build

Requirements: macOS 13+, Swift 5.9+ / Xcode CLT.

```bash
git clone https://github.com/yazydzhi/InfiniWake.git
cd InfiniWake
./scripts/build-app.sh
open .build-app/InfiniWake.app
```

For **closed-lid** keep-awake (like Capsomnia), install the narrow `pmset` helper once:

```bash
./scripts/install-helper.sh
```

## Usage

- **F4** (or click the menu-bar icon) — toggle keep-awake
- Right-click menu — timer presets, settings, about, quit
- Auto-off: ∞ or 15 min–8 h (then releases sleep prevention and runs `pmset sleepnow`)

### Indicators

- On + ∞ → Caps Lock LED on, menu bar shows `∞`
- On + timer → LED on, menu bar shows remaining time
- Off → LED off, menu bar shows dimmed `∞` or preset

## Uninstall helper

```bash
sudo rm -f /Library/PrivilegedHelperTools/infiniwake-pmset /etc/sudoers.d/infiniwake-pmset
sudo pmset -a disablesleep 0
```

## License

InfiniWake is **free software** under the [MIT License](LICENSE).  
© 2026 Vladimir Yazydzhi
