import Foundation

public protocol PluginCapability: AnyObject {
    var capabilityId: String { get }
    var displayName: String { get }
    var isEnabled: Bool { get }
}