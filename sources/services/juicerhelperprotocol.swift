import Foundation

/// An Objective-C compatible XPC protocol defining privileged system operations executed by the Juicer helper daemon.
///
/// `JuicerHelperProtocol` establishes the inter-process communication (IPC) contract between the main application bundle
/// and the elevated privileges helper service (`com.even.juicer.helper`). Since XPC requires Objective-C runtime compatibility,
/// this protocol is annotated with `@objc(JuicerHelperProtocol)`.
///
/// - Note: Methods defined in XPC protocols must have asynchronous signatures with reply blocks taking completion results.
@objc(JuicerHelperProtocol)
public protocol JuicerHelperProtocol {
    /// Queries the helper daemon's installed version string.
    ///
    /// - Parameter reply: A completion handler invoked with the version string (e.g., `"1.1.0"`).
    func checkDaemonVersion(reply: @escaping (String) -> Void)

    /// Modifies Transparency, Consent, and Control (TCC) privacy permissions for a specified client and service.
    ///
    /// - Parameters:
    ///   - client: The application identifier or bundle ID requesting permission modification.
    ///   - service: The TCC service name (e.g., `kTCCServiceSystemPolicyAllFiles`).
    ///   - allow: A boolean flag indicating whether permission should be granted (`true`) or revoked/reset (`false`).
    ///   - reply: A completion closure receiving a status boolean and a descriptive result message.
    func modifyTCCPermission(client: String, service: String, allow: Bool, reply: @escaping (Bool, String) -> Void)

    /// Overwrites `/etc/hosts` system file contents safely after creating a backup copy.
    ///
    /// - Parameters:
    ///   - content: The raw string content to be written to `/etc/hosts`.
    ///   - backupPath: The file path destination where the current `/etc/hosts` should be copied before replacement.
    ///   - reply: A completion closure receiving a status boolean and a descriptive result message.
    func writeHostsFile(content: String, backupPath: String, reply: @escaping (Bool, String) -> Void)

    /// Sends a POSIX signal to terminate a targeted process ID.
    ///
    /// - Parameters:
    ///   - pid: The target process identifier.
    ///   - signal: The numeric POSIX signal number (e.g., `SIGTERM` or `SIGKILL`).
    ///   - reply: A completion closure receiving a status boolean and a descriptive result message.
    func terminateProcess(pid: Int32, signal: Int32, reply: @escaping (Bool, String) -> Void)

    /// Removes system cache directories or files located within safe cache boundaries.
    ///
    /// - Parameters:
    ///   - path: The file system path of the cache directory or file targeted for deletion.
    ///   - reply: A completion closure receiving a status boolean and a descriptive result message.
    func purgeSystemCache(path: String, reply: @escaping (Bool, String) -> Void)
}

/// Constants used for identifying and negotiating versions with the privileged Juicer helper daemon.
public enum JuicerHelperConstants {
    /// The Mach service bundle identifier registered with `launchd` / `SMAppService`.
    public static let serviceIdentifier = "com.even.juicer.helper"

    /// The current operational version of the Juicer helper protocol.
    public static let version = "1.1.0"
}
