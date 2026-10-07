# InfiniWake

**Free · MIT License** · macOS menu-bar keep-awake utility

**Version 1.1.5** · Author: **Vladimir Yazydzhi** (Владимир Языджи)  
**Universal binary** — arm64 and x86_64.

InfiniWake keeps your Mac awake with a dedicated hotkey (default **F4**).  
Caps Lock can be used as a **physical LED indicator** or as the toggle (optional in Settings). While keep-awake is on with LED mode, real CAPS typing is filtered out (Accessibility required).

If a third-party keyboard driver remaps Caps Lock LED control, InfiniWake may adjust local LED settings for the built-in keyboard so the physical light can stay on (a backup of that config is written next to it when changed).

UI languages: **English** / **Русский** (auto from system language, or choose in Settings).

---

## Install (prebuilt)

1. Open the latest release: **[Releases](https://github.com/yazydzhi/InfiniWake/releases/latest)**
2. Download **`InfiniWake-1.1.5.dmg`** (universal: arm64 + x86_64)
3. Open the disk image → drag **InfiniWake** onto **Applications** → eject the volume
4. Open **InfiniWake** from Applications (first launch: right-click → Open, or allow in **Privacy & Security** if Gatekeeper blocks an ad-hoc signed build)
5. You should see **∞** in the menu bar

> Always run the app from **`/Applications/InfiniWake.app`**.  
> Running from Downloads/build folders breaks Accessibility after rebuilds (macOS treats it as a new app).

### Closed-lid keep-awake (optional, recommended)

By default InfiniWake uses a power assertion (works well with the lid **open**).  
To keep working with the **lid closed** (AI agents, SSH, builds), install the narrow helper once:

```bash
# from a clone of this repo, or after unzipping sources
./scripts/install-helper.sh
```

This installs `/Library/PrivilegedHelperTools/infiniwake-pmset` and a sudoers rule that allows only:

`on` · `off` · `display-sleep`

---

## Setup

### 1. Accessibility (for Caps Lock LED without real CAPS)

Needed only if **Caps Lock LED** is enabled in Settings (default: on).

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **InfiniWake**
3. If the toggle was already on: turn it **off → on**
4. **Quit InfiniWake completely** and open it again from `/Applications`

macOS applies Accessibility only after the app restarts. Keep-awake itself works without this permission; the LED indicator does not.

### 2. Hotkey

Default toggle key: **F4**.  
Change it in **Settings** (right-click menu bar icon → Settings): Caps Lock, F1–F12, and common shortcuts.

### 3. Language

**Settings → Language**:

- **System** — Russian if macOS preferred language is `ru*`, otherwise English
- **English** / **Русский** — force UI language

### 4. Auto-off timer

In the menu or Settings: **∞ Unlimited** or 15 minutes–8 hours.  
When the timer ends, InfiniWake turns off keep-awake and runs `pmset sleepnow`.

### 5. Launch at login

Optional checkbox in Settings.

---

## Usage

| Action | How |
|--------|-----|
| Toggle keep-awake | Hotkey (default **F4**) or left-click menu bar icon |
| Menu (timer, settings, about) | Right-click (or ⌃-click) the icon |
| Status on + ∞ | Caps Lock LED on, menu bar shows `∞` |
| Status on + timer | LED on, menu bar shows remaining time |
| Status off | LED off, menu bar shows dimmed `∞` / preset |

Caps Lock does **not** have to control InfiniWake. By default it is only the LED indicator (language switching still works). You can optionally set Caps Lock as the toggle in Settings (ON = awake, OFF = normal sleep).

---

## Build from source

Requirements: macOS 13+, Swift 5.9+ / Xcode Command Line Tools.

```bash
git clone https://github.com/yazydzhi/InfiniWake.git
cd InfiniWake
./scripts/build-app.sh
# installs to /Applications/InfiniWake.app and also leaves a copy in .build-app/
open /Applications/InfiniWake.app
```

Optional closed-lid helper:

```bash
./scripts/install-helper.sh
```

Build a drag-to-Applications DMG (requires [`create-dmg`](https://github.com/create-dmg/create-dmg): `brew install create-dmg`):

```bash
./scripts/build-dmg.sh 1.1.5
# → dist/InfiniWake-1.1.5.dmg (universal)
```

`build-app.sh` produces a **universal** binary (`arm64` + `x86_64`) via `lipo`.
---

## Uninstall

```bash
# Quit InfiniWake first
rm -rf /Applications/InfiniWake.app

# If you installed the closed-lid helper:
sudo rm -f /Library/PrivilegedHelperTools/infiniwake-pmset /etc/sudoers.d/infiniwake-pmset
sudo pmset -a disablesleep 0
```

Also remove InfiniWake from **System Settings → Privacy & Security → Accessibility** if listed.

---

## License

InfiniWake is **free software** under the [MIT License](LICENSE).  
© 2026 Vladimir Yazydzhi
