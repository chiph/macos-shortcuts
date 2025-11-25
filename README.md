## macos-shortcuts Overview

**macos-shortcuts** is a shell script tool for macOS that creates custom app shortcuts with a clean, native look—serving as a Launchpad replacement or Dock organizer. Unlike standard Finder aliases, shortcuts made with this tool appear as full applications and do *not* display the arrow overlay in the Dock.

### Note: Use at your own risk - I've run it a few times and it seems to work, but I make no guarantees.
---

### What Does It Do?

- Automatically scans the default macOS applications directories:
  - `/Applications`
  - `/System/Applications`
- For each found app, generates a self-contained shortcut "application" bundle in `~/AppShortcuts`.
- Uses Automator's Application Stub under the hood so shortcuts behave just like actual apps.
- **Extracts and copies the original app's icon** to each shortcut, including support for modern macOS apps that use compiled asset catalogs (`Assets.car`).
- All created shortcuts can be placed in the Dock without the distracting alias arrow overlay.
- Produces color-coded terminal output to indicate success, warnings, or errors.

---

### How Does It Work? (Technical Notes)

1. **Setup & Discovery**
   - The script locates installed applications in standard system directories.
   - Prepares a destination folder `~/AppShortcuts` to store generated shortcuts.

2. **Shortcut Bundle Generation**
   - For each detected application:
     - Creates a new `.app` bundle directory structure.
     - Copies the Automator Application Stub binary to serve as the shortcut's executable.
     - Dynamically generates an XML workflow (`document.wflow`) to launch the target app via Automator.
       - The workflow references `/System/Library/Automator/Launch Application.action` and embeds the target app's path.
       - XML-safe escaping ensures all characters/paths are handled correctly.
     - **Extracts the app's icon** using multiple strategies:
       - For modern apps with `Assets.car` (Calendar, System Settings, Books, etc.), uses a Swift helper script to extract icons via native macOS APIs.
       - For traditional apps, copies the `.icns` file specified in the app's `Info.plist`.
       - Falls back to finding the largest icon file when needed.

3. **Result**
   - Each shortcut bundle is a genuine macOS application:
     - Can be launched, docked, or managed like any standard app.
     - *Does not* show a shortcut arrow overlay.
     - Displays the original app's icon.

4. **No Arrow Overlay?**
   - Standard Finder aliases or symlinks show a small arrow overlay in the Dock.
   - By creating proper `.app` bundles via Automator, this script sidesteps that cosmetic indicator, making shortcuts appear identical to regular applications.

---

### Features & Intended Audience

- Simple: just run the script to populate your `~/AppShortcuts` folder.
- **Full icon support** including modern macOS apps (Calendar, System Settings, Books, etc.)
- Intelligently extracts icons from both traditional `.icns` files and compiled `Assets.car` catalogs.
- No configuration or external dependencies required - everything needed is built into macOS.
- Ideal for users who want a lightweight, customizable app launcher without the clutter or branding of Launchpad or other third-party tools.

---

### Usage

1. Clone or download this repo.
2. Run `generate_app_shortcuts.sh` from Terminal:
   ```sh
   bash generate_app_shortcuts.sh
   ```
3. Drag desired shortcuts from `~/AppShortcuts` to your Dock or preferred location.
   - Remove or rename shortcut bundles as you wish.

---

### Dependencies

- **Required:**
  - macOS with Automator pre-installed (standard on all macOS versions)
  - Swift runtime (pre-installed on macOS)
  - `iconutil` command-line tool (pre-installed on macOS)

- **Included:**
  - `extract_icon.swift` - Helper script for extracting icons from modern macOS apps with compiled asset catalogs

- **No external dependencies** - All required tools are built into macOS.

---
