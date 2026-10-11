# 🍊 Juicer

<div align="center">

<img src="sources/resources/assets.xcassets/appicon.appiconset/icon_128x128.png" width="128" height="128" alt="Juicer App Icon" />

**The Ultimate All-In-One Companion Suite & Developer Utility For macOS**  
*High-performance, native SwiftUI studio unifying 16 companion workspaces for package management, disk analysis, and runtime maintenance.*

[![Platform: macOS Sonoma+](https://img.shields.io/badge/Platform-macOS%2014%2B%20(Sonoma%20%2F%20Sequoia)-blue.svg?style=flat-square&logo=apple)](https://apple.com)
[![Swift: 5.10+](https://img.shields.io/badge/Swift-5.10%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Release: v1.1.3](https://img.shields.io/badge/Release-v1.1.3-blue.svg?style=flat-square&logo=github)](https://github.com/AMFI-Disable/Juicer/releases)
[![Tests: 71 / 71 Passed](https://img.shields.io/badge/Tests-71%20%2F%2071%20Passed%20(100%25)-success.svg?style=flat-square&logo=checkmarx)](#automated-tests-and-quality-assurance)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](license)
[![Pricing: Free & Open-Source](https://img.shields.io/badge/Pricing-100%25%20Free%20%26%20Open%20Source-success.svg?style=flat-square)](#key-capabilities)
[![Privacy: Zero Telemetry](https://img.shields.io/badge/Privacy-Zero%20Telemetry%20%2F%20100%25%20Local-purple.svg?style=flat-square)](#privacy-and-security-first)

</div>

> [!NOTE]
> **Project Archived & Sunset Notice**
> Juicer has reached end-of-life and is officially archived. The final stable release is [v1.1.3](https://github.com/AMFI-Disable/Juicer/releases/tag/v1.1.3). The repository remains available in read-only mode for historical reference and pre-built binaries. No further updates, issues, or pull requests will be accepted.

---

## 🧭 Table Of Contents

- [Overview & Core Value](#overview-and-core-value)
- [Bundled Workspaces](#bundled-workspaces)
- [Key Capabilities](#key-capabilities)
- [Installation Guide](#installation-guide)
- [Technical Architecture](#technical-architecture)
- [Automated Tests & Quality Assurance](#automated-tests-and-quality-assurance)
- [Privacy & Security First](#privacy-and-security-first)
- [License & Open Source](#license-and-open-source)

---

## ⚡ Overview And Core Value <a id="overview-and-core-value"></a>

Juicer is the ultimate open-source companion utility for **macOS developers and power users**. It is a 100% free, local-first suite that consolidates package managers, disk analyzers, app uninstallers, launchd editors, developer cache pruners, hosts file editors, and system tweaks into a high-performance native SwiftUI app.

> Prefer a focused Homebrew experience? BrewStore is being extracted as an independent Juicer family app for casks, formulae, services, taps, updates, and preview-first removal of Homebrew-installed apps. The all-in-one Juicer Suite remains available for advanced users.

---

## 🧭 Bundled Workspace Companion Suite <a id="bundled-workspaces"></a>

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

## 🛠️ Key Capabilities <a id="key-capabilities"></a>

- **App Store Software Center 🛍️**: Easily manage Homebrew Casks (GUI) and Formulae (CLI) in a modern layout with category and pricing classification.
- **Space Lens (Disk Visualizer) 🔍**: Proportional squarified Treemaps and Canvas-drawn Sunburst charts with path copying and staged batch discard.
- **Deep App Uninstaller 🧹**: Drag and drop any `.app` to remove caches, app support, plists, containers, `ByHost Preferences`, and helper tools.
- **Orphan Directory Sweeper**: Locate and clean up orphaned files left behind by deleted applications.
- **Clipboard History Manager 📋**: Local-first text clipboard cache with pinned items, search filtering, formatting stripping, and hotkeys.
- **Status Menu Bar Monitor 📈**: Live system disk and physical memory utilization widget embedded directly in the macOS menu bar.
- **Trusted Script Plugins 🧩**: Execute custom shell scripts (`.sh`, `.command`, `.zsh`) securely with real-time log output.
- **DNS Profile Manager & Ad-Blocker 🛡️**: Switch local DNS profiles and apply StevenBlack's hosts filter to `/etc/hosts`.

---

## 🍺 Installation <a id="installation-guide"></a>

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

### Method C: Build From Source

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

## 🏗️ Technical Architecture & Build Setup <a id="technical-architecture"></a>

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

## 🧪 Automated Tests And Quality Assurance <a id="automated-tests-and-quality-assurance"></a>

Juicer maintains a comprehensive automated test suite covering safety bounds, navigation, and state bridges:

```bash
# Generate Xcode project and run full automated test suite
xcodegen generate
xcodebuild test \
  -project juicer.xcodeproj \
  -scheme juicer \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO
```

---

## 🛡️ Privacy And Security First <a id="privacy-and-security-first"></a>

- **Zero Telemetry**: No third-party network pings, tracking cookies, or diagnostic phoning home.
- **Local-First Execution**: All diagnostics, disk indexing, and clipboard history remain completely on device.
- **Trash Deletion Safe Guards**: File deletions and package removals route safely through native macOS Trash.

---

## 🤖 Automated Contributors And AI Reviewers

Juicer is continuously audited, linted, and reviewed by automated AI agents and workflow bots:

- 🐰 **[CodeRabbit](https://coderabbit.ai)** (`@coderabbitai`) - Context-aware AI PR reviewer & security auditor.
- 🛡️ **[CodeQL](https://codeql.github.com)** (`github-advanced-security`) - Continuous static application security testing (SAST).
- 📦 **[Dependabot](https://github.com/dependabot)** (`@dependabot[bot]`) - Automated dependency updates.
- 🧹 **[Stale Bot](https://github.com/actions/stale)** (`@actions/stale[bot]`) - Issue triage & PR maintenance.

---

## 📄 License And Open Source <a id="license-and-open-source"></a>

Licensed under the [MIT License](license). Copyright (c) 2026 AMFI-Disable.
All contributors are expected to adhere to the [Code of Conduct](code_of_conduct.md).
