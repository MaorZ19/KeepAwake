// State shared between the menu bar app and the Control Center widget
// extension — two separate processes. The widget runs sandboxed, so the
// state lives as a JSON file in the app group container (the one location
// both processes can reach), synced via a distributed notification.
import Foundation

enum SharedState {
    static let groupID = "group.com.maor.keepawake"
    static let controlKind = "com.maor.KeepAwakeBar.control"
    static let changedNote = Notification.Name("com.maor.keepawake.changed")

    private static var stateURL: URL {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/\(groupID)")
        return base.appendingPathComponent("state.json")
    }

    static var isEnabled: Bool {
        guard let data = try? Data(contentsOf: stateURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Bool],
              let on = obj["enabled"] else { return true }
        return on
    }

    static func setEnabled(_ on: Bool) {
        let url = stateURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: ["enabled": on]) {
            try? data.write(to: url, options: .atomic)
        }
        DistributedNotificationCenter.default().postNotificationName(
            changedNote, object: nil, userInfo: nil, deliverImmediately: true)
    }
}
