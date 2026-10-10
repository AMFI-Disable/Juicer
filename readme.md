# Juicer

<p align="center">
  <img src="sources/resources/assets.xcassets/appicon.appiconset/icon_128x128.png" width="128" height="128" alt="Juicer App Icon" />
</p>

<p align="center">
  <b>The ultimate all-in-one companion suite and developer utility for macOS!</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-V1.1.0-blue" alt="Version" />
  <a href="license"><img src="https://img.shields.io/badge/License-MIT-green" alt="License" /></a>
  <a href="https://developer.apple.com/macos"><img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-lightgrey?logo=apple" alt="Platform" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift" /></a>
</p>

Juicer is the ultimate open-source companion utility for **macOS developers and power users**. It is a 100% free, local-first suite that consolidates package managers, disk analyzers, app uninstallers, launchd editors, developer cache pruners, hosts file editors, and system tweaks into a high-performance native SwiftUI app.

> Prefer a focused Homebrew experience? BrewStore is being extracted as an independent Juicer family app for casks, formulae, services, taps, updates, and preview-first removal of Homebrew-installed apps. The all-in-one Juicer Suite remains available for advanced users.

---

## 🧭 Bundled Workspace Companion Suite (V1.1.0)

Juicer organizes its extensive feature set across **16 specialized companion workspaces**:

- 🚀 **Juicer Hub**: Central launcher and interactive launchpad canvas supporting Pan & Zoom gestures, edge-to-edge full screen modes, and launch bypass options.
- 📦 **Juicer Store**: Modern Homebrew Cask (GUI) & Formula (CLI) package manager with background metadata resolution, tap manager, service controller, and Brewfile sync.
- ⚡ **System & Hardware**: Real-time CPU/GPU gauges, memory pressure, battery health, power schedules, and thermal/fan sensors.
- 🌐 **Network & Ports**: Wi-Fi survey tools, speed tester, open port listener, DNS diagnostics, active VPN profiles, and firewall rules.
- 🛡️ **Security & Privacy**: TCC permission audit, privacy cabinet, FileVault inspector, quarantine stripper, anti-keylogger scanner, and app locker.
- 💾 **Disk & Storage**: Space Lens disk visualizer (Treemaps & Sunburst charts), developer cache cleaner, large file locator, duplicate finder, and storage snapshot manager.
- 🛠️ **Developer Suite**: SDK runtime switcher, trusted script plugins runner, local web server, code snippet expander, and environment profiles.
- 🌿 **Git Studio**: Repository workbench, commit history, branch operations, effort analytics, and developer account helpers.
- 🐳 **Docker Studio**: Container inventory, lifecycle actions, logs, Compose stacks, and disk-usage cleanup.
- ✨ **AI Studio**: Local Ollama and LM Studio discovery, prompt tools, model benchmarks, and local chat when an engine is available.
- 🗄️ **Database Studio**: Local database daemon checks, SQLite inspection, Redis browsing, and backup helpers.
- 📡 **API Studio**: REST requests, cURL import, authentication headers, history, benchmarks, and load tests.
- 🔄 **Converter Studio**: Offline document, image, schema, archive, and media conversion tools.
- ⚙️ **System Configs**: App uninstaller, orphan finder, launch daemon editor, hidden macOS tweaks, log rotator, and system optimizer.
- 🧰 **Utilities & Desktop**: Window tiler, clipboard manager, hot corners, color loupe, screen ruler, PDF toolbox, and desktop helper widgets.
- 🌟 **Creator Studio**: Open-source project discovery, repository cloning, and ecosystem shortcuts.

---

## 🛠️ Key Capabilities

- **App Store Software Center 🛍️**: Easily manage Homebrew Casks (GUI) and Formulae (CLI) in a modern layout with category and pricing classification.
- **Space Lens (Disk Visualizer) 🔍**: Proportional squarified Treemaps and Canvas-drawn Sunburst charts with path copying and staged batch discard.
- **Deep App Uninstaller 🧹**: Drag and drop any `.app` to remove caches, app support, plists, containers, `ByHost Preferences`, and helper tools.
- **Orphan Directory Sweeper**: Locate and clean up orphaned files left behind by deleted applications.
- **Clipboard History Manager 📋**: Local-first text clipboard cache with pinned items, search filtering, formatting stripping, and hotkeys.
- **Status Menu Bar Monitor 📈**: Live system disk and physical memory utilization widget embedded directly in the macOS menu bar.
- **Trusted Script Plugins 🧩**: Execute custom shell scripts (`.sh`, `.command`, `.zsh`) securely with real-time log output.
- **DNS Profile Manager & Ad-Blocker 🛡️**: Switch local DNS profiles and apply StevenBlack's hosts filter to `/etc/hosts`.

---

## 🍺 Installation

### Method A: Install via Homebrew Tap (Recommended)

Install Juicer using our official Homebrew Tap:

```bash
# Tap the repository
brew tap AMFI-Disable/juicer

# Install Juicer Cask
brew install --cask juicer
```

### Method B: Manual DMG Package (GitHub Releases)

Download the verified `.dmg` package from [GitHub Releases](https://github.com/AMFI-Disable/Juicer/releases). Verify the SHA-256 checksum after download:

```bash
shasum -a 256 juicer-1.1.3.dmg
```

#### macOS Gatekeeper Clearance (Unnotarized Open-Source Build)

Because Juicer is an open-source build provided without a paid Apple Developer ID certificate ($99/year), macOS Gatekeeper quarantines downloaded application bundles on first launch.

To clear the quarantine flag via Terminal:

```bash
sudo xattr -r -c /Applications/Juicer.app
```

Alternatively, open **System Settings > Privacy & Security**, scroll down to the Security section, and click **Open Anyway** (or hold `Control` while clicking the app in Finder and select **Open**).

---

### Method C: Build from Source

Juicer can be compiled locally from source:

```bash
# Install XcodeGen
brew install xcodegen

# Generate Xcode Project
xcodegen generate

# Build Debug or Release target
xcodebuild build -project juicer.xcodeproj -scheme juicer -configuration Release
```

---

## 🏗️ Technical Architecture & Build Setup

- **Platform**: macOS 14.0+
- **Language**: Swift / SwiftUI (currently compiled in Swift 5 language mode)
- **Code Signing**: Deep ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`) with Sparkle framework re-signing to eliminate dyld Team ID launch errors.
- **Project Generator**: Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build `juicer.xcodeproj` from `project.yml`.

To build locally:

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project juicer.xcodeproj -scheme juicer -configuration Debug
```

---

## 🤖 Automated Contributors & AI Reviewers

Juicer is continuously audited, linted, and reviewed by automated AI agents and workflow bots:

- 🐰 **[CodeRabbit](https://coderabbit.ai)** (`@coderabbitai`) - Context-aware AI PR reviewer & security auditor.
- 🛡️ **[CodeQL](https://codeql.github.com)** (`github-advanced-security`) - Continuous static application security testing (SAST).
- 📦 **[Dependabot](https://github.com/dependabot)** (`@dependabot[bot]`) - Automated dependency updates.
- 🧹 **[Stale Bot](https://github.com/actions/stale)** (`@actions/stale[bot]`) - Issue triage & PR maintenance.

---

## 📜 License & Code of Conduct

This project is licensed under the [MIT License](license).
All contributors are expected to adhere to the [Code of Conduct](code_of_conduct.md).
