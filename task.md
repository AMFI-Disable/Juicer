# Juicer Studio Reliability and Safety Tasks

## Store Studio

1. Give Sync Database visible progress, success, failure, retry, and last-updated states; the tested click produced no feedback.
2. Make Taps → Validate Health observable with per-tap results, progress, errors, and retry; the tested action produced no visible result.
3. Make Formula Updates show installed/current/latest versions and an explicit update action instead of only “Installed.”
4. Separate Homebrew formulas, external packages, casks, and unknown records in the UI; Installed Formulae currently mixes entries marked “External.”
5. Replace the persistent “Fast loaded … Fetching metadata…” banner with scoped, cancellable background-task status and a terminal state.
6. Require clear confirmation and show affected paths before cleanup, orphan removal, uninstall, and other destructive operations.
7. Keep dry-run results bound to the exact operation and refresh them after state changes; expose the source and timestamp of cleanup candidates.
8. Add regression tests for search/filter/pagination, sync failures, tap health, metadata refresh, cask details, cleanup dry runs, and service discovery.

## System Studio

1. Bound Live Status Monitor refreshes with timeout, error, retry, and last-success states; it remained on “Collecting system metrics…” with Refresh disabled.
2. Explicitly report unsupported hardware, such as no battery or no fan telemetry, instead of leaving cards in “Syncing” with zero-like values.
3. Make refresh controls cancellable and ensure every system-metrics request reaches a terminal state.
4. Give Processes and Startup Item Manager explicit loading, permission, empty, and error states; both showed empty lists without context.
5. Parse Services output into structured rows with label, PID, status, source, and readable status text; the current view exposes a raw PID/status/label dump.
6. Keep service controls read-only by default and require scoped confirmation for start/stop/reload actions, with audit feedback.
7. Scope the global Homebrew/background activity indicator to the originating tool so unrelated system views do not inherit stale status.
8. Add a clear lock-screen recovery message and a test mode for System Log Viewer when the Mac is locked.
9. Add regression tests for unsupported hardware, metric timeouts, empty/permission-denied lists, service parsing, and safe control confirmations.

## Network Studio

1. Bound Speed Test execution with progress, elapsed time, timeout, failure, retry, and last-result states; it stayed on “Downloading a test payload…” with no result.
2. Fix cancellation so Cancel aborts the request, clears busy state, and restores the idle view; repeated Cancel clicks had no effect.
3. Prevent duplicate network operations and show the endpoint, payload size, and elapsed time for active tests.
4. Parse DNS `dig` output into status, resolver, query time, answers, DNSSEC, and errors, with raw output optional; the current result is an opaque transcript.
5. Validate hostname, resolver, port, and transport inputs before execution and explain DNS/privacy implications.
6. Make LAN discovery show progress, timeout, result count, permission errors, and the queried interface/service; `_http._tcp` returned no visible result or error.
7. Add privacy context for LAN, Wi-Fi, public-IP, and geolocation tools, including external destinations and data sent.
8. Make Port Scanner stateful and safe: validate ranges, show per-port states, bound each probe, and warn before scanning non-local hosts; the tested scan stayed in Syncing with no results.
9. Show listener bind address, port, owning process, exposure, and stop behavior in structured rows; require confirmation before stopping a listener.
10. Add regression tests for network timeouts/cancellation, DNS parsing, empty discovery, port validation, permission failures, and privacy disclosures.

## Security Studio

1. Replace the “SANDBOX STUB” privacy cabinet with a real, clearly scoped TCC data source—or label it as sample/demo data and disable revoke affordances. The cabinet showed fixed-looking records and claimed `tccutil` integration.
2. Make Privacy Scanner report actual permission category, grant state, source, timestamp, and confidence per app. It listed 460 installed apps, but visible rows only said “Review in System Settings.”
3. Add visible scan progress, cancellation, errors, and completion timestamps; the Scan action produced no observable change or result state.
4. Make permission revocation actionable only when backed by a verified macOS operation; show the exact service/app target, authorization requirement, and result.
5. Give empty security collections explicit empty states. App Locker showed an empty list without saying that no apps were protected.
6. Make sensitive operations explicit and gated: keychain audit, app authentication, lock-screen, secure delete, quarantine stripping, and power/security changes need clear scope, confirmation, and success/failure feedback.
7. Replace title-only diagnostic tabs with real read-only results or mark them “Not implemented.” TCC Audit, KEXT, and Dylib tabs rendered only a heading with no controls or findings.
8. Improve heuristic scanner findings: show full path, signing/notarization status, rule rationale, confidence, and allowlist/false-positive handling. Anti-Keylogger Scanner reported `com.baidu.InputService.plist` as one heuristic match without those details.
9. Parse Network Exposure Monitor output into process, PID, protocol, bind address, port, interface, and exposure; the current view is raw `lsof` text and does not distinguish loopback from wildcard listeners clearly.
10. Make USB Device Guard explain device identity, whitelist matching, and limitations; distinguish “no devices found” from unavailable hardware/permission.
11. Add regression tests covering TCC states, stub/demo data detection, scan timeouts, empty vaults/lists, authorization denial, heuristic false positives, socket parsing, and no unintended mutations.

## Verification Notes

- Tested Store, System, Network, and Security Studio launches and navigation from the Applications copy `/Applications/Juicer.app`.
- Store, System, Network, and Security findings above are based on observed UI behavior; no destructive cleanup, uninstall, service mutation, firewall/VPN change, secure deletion, credential entry, or security-setting change was performed.
- System Log Viewer was not fully tested because the Mac became locked and automatic unlock was unavailable.
