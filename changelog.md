# changelog

## V1.1.3 — 2026-08-06

### added

- **Complete CaskHub Integration Suite**: Native GUI sudo dialog (`SUDO_ASKPASS`), 30d/90d/365d analytics top charts shelf, zombie cask repair, MAS receipt safeguards, and HTTP HEAD download size resolver.
- **Homebrew Cask Upgrade**: Official release V1.1.3 published to `amfi-disable/homebrew-juicer`.

---

## V1.1.2 — 2026-08-06

### added

- **Native Password Authorization (`SUDO_ASKPASS`)**: Native macOS Security prompt for privileged `.pkg` cask installations.
- **Top Charts & Popularity Shelf**: Live 30-day, 90-day, and 1-year Homebrew cask popularity rankings.
- **Zombie Cask Repair**: 1-click purge or reinstall for orphaned Caskroom receipts.
- **Mac App Store (MAS) Protection**: `_MASReceipt` detection preventing destructive Homebrew overwrites.

---

## V1.1.1 — 2026-08-06

### added

- **Juicer Store Studio Package Adoption**: `--adopt` preflight checks and `--force` replace fallbacks.
- **Homebrew Locks Auto-Fixer**: Automatic detection and 1-click purging of stale lock files.
- **Standalone App Discovery**: Scan all macOS applications installed outside Homebrew.

---

## V1.1.0 — 2026-07-25

### added

- **Global Command Palette (`Cmd+Shift+K`)**: Instant search overlay across 40+ Juicer tools.
- **SDK Version Manager**: Manage Node.js, Python, Ruby, Rust, and Homebrew versions.
- **Better Cmd-Tab Window Switcher**: Application switcher with live window previews.

---

## V1.0.3 — 2026-07-22

### added

- **Environment Variable Profiles & Secret Masker**: Manage `.env` profiles and mask credentials.
- **Per-Process Real-Time Network Bandwidth Monitor**: Live download/upload tracking per process.
- **App Language Asset Stripper**: Reclaim disk space by removing unused `.lproj` folders.
- **Vision OCR Screen Area Grabber**: Instant text recognition from screen selections.
- **Natural Language zsh Command Converter**: Translate plain text prompts into shell commands.

---

## V1.0.1 — 2026-07-20

### fixed

- Concurrency safety and type-safe Accessibility API error bounds.
- Embedded high-res `AppIcon.icns` asset and Homebrew cask auto-updates.

---

## V1.0.0 — 2026-07-15

### added

- **Initial Launch**: Developer Cache Pruner, Storage Analyzer, Deep Uninstaller, System Tweaks, Network Monitor, and System Menu Bar Extras.
