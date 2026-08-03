import Foundation

@objc(JuicerHelperProtocol)
public protocol JuicerHelperProtocol {
    func checkDaemonVersion(reply: @escaping (String) -> Void)
    func modifyTCCPermission(client: String, service: String, allow: Bool, reply: @escaping (Bool, String) -> Void)
    func writeHostsFile(content: String, backupPath: String, reply: @escaping (Bool, String) -> Void)
    func terminateProcess(pid: Int32, signal: Int32, reply: @escaping (Bool, String) -> Void)
    func purgeSystemCache(path: String, reply: @escaping (Bool, String) -> Void)
}

public enum JuicerHelperConstants {
    public static let serviceIdentifier = "com.even.juicer.helper"
    public static let version = "1.1.0"
}
