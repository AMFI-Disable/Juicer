export const siteConfig = {
  "title": "Juicer",
  "repoUrl": "https://github.com/AMFI-Disable/Juicer",
  "category": "macOS Native App",
  "accent": "#2EA3F2",
  "tagline": "The ultimate all-in-one companion suite and local-first system utility for macOS power users and developers.",
  "primaryCta": {
    "label": "Install via Homebrew",
    "href": "#quick-start"
  },
  "secondaryCta": {
    "label": "View on GitHub",
    "href": "https://github.com/AMFI-Disable/Juicer"
  },
  "quickCmd": "brew tap AMFI-Disable/juicer && brew install --cask juicer",
  "features": [
    {
      "title": "16 Companion Workspaces",
      "desc": "Unifies app uninstallers, orphan file cleaners, launchd editors, developer cache pruners, and DNS/hosts tools in one SwiftUI studio."
    },
    {
      "title": "Orphan & Cache Pruning",
      "desc": "Safely reclaim gigabytes from Xcode DerivedData, Homebrew caches, container leftovers, and stale application support files."
    },
    {
      "title": "LaunchServices & Gatekeeper",
      "desc": "Inspect background daemons, manage login items, override LaunchServices defaults, and clear quarantine flags cleanly."
    },
    {
      "title": "Native SwiftUI Performance",
      "desc": "Built with Swift 5.10+ for macOS 14+ (Sonoma & Sequoia) with zero Electron overhead and instant cold starts."
    },
    {
      "title": "Dry-Run Safety Previews",
      "desc": "Every destructive system cleanup previews exact file paths and byte sizes before moving items to Trash."
    },
    {
      "title": "Zero Telemetry",
      "desc": "100% local-first execution with no analytics, no background phone-home, and full MIT-licensed transparency."
    }
  ],
  "steps": [
    {
      "title": "Discover & Index",
      "desc": "Scans macOS application bundles, LaunchAgents, developer toolchains, and cache directories in parallel."
    },
    {
      "title": "Preview Impact",
      "desc": "Computes exact disk footprints, dependency links, and safety classifications before any mutation."
    },
    {
      "title": "Execute & Audit",
      "desc": "Applies atomic Trash-first cleanups and system overrides with reversible audit logs."
    }
  ],
  "installCmds": [
    {
      "label": "Homebrew Cask (Recommended)",
      "cmd": "brew tap AMFI-Disable/juicer && brew install --cask juicer"
    },
    {
      "label": "Build from Source",
      "cmd": "git clone https://github.com/AMFI-Disable/Juicer.git && cd Juicer && xcodegen generate && swift build"
    }
  ],
  "requirements": [
    "macOS 14.0+ (Sonoma / Sequoia)",
    "Apple Silicon or Intel Mac",
    "71 / 71 automated tests passing"
  ],
  "hubName": "AMFI Studio",
  "hubHash": "studio",
  "previewTabs": [
    {
      "tab": "App Uninstaller",
      "title": "Orphan-Free Removal",
      "body": "Scans /Applications, ~/Library/Application Support, Caches, Preferences, and LaunchAgents before moving leftovers to Trash."
    },
    {
      "tab": "Dev Cache Pruner",
      "title": "Reclaim Xcode & Brew Space",
      "body": "Safely previews DerivedData, CocoaPods, Simulator runtimes, and Homebrew download caches with exact byte totals."
    },
    {
      "tab": "Launchd & DNS",
      "title": "System Service Control",
      "body": "Inspect user/system plists, toggle background daemons, and switch local DNS profiles with zero terminal guesswork."
    }
  ]
} as const;
