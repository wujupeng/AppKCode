import Foundation

public extension Notification.Name {
    static let appkOpenFolderRequested = Notification.Name("AppKOpenFolderRequested")
    static let appkSaveRequested = Notification.Name("AppKSaveRequested")
    static let appkSaveAsRequested = Notification.Name("AppKSaveAsRequested")
    static let appkFileOpenRequested = Notification.Name("AppKFileOpenRequested")
    static let appkCursorJumpRequested = Notification.Name("AppKCursorJumpRequested")
    static let appkEditorError = Notification.Name("AppKEditorError")
    static let appkEditorJumpToLine = Notification.Name("AppKEditorJumpToLine")
    static let appkApprovalRequested = Notification.Name("AppKApprovalRequested")
    static let appkApprovalResolved = Notification.Name("AppKApprovalResolved")
    static let appkRestoreWorkspace = Notification.Name("AppKRestoreWorkspace")
    static let appkCloseRequested = Notification.Name("AppKCloseRequested")
}
