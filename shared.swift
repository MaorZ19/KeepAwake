// State shared between the menu bar app and the Control Center widget
// extension — two separate processes, synced via a JSON file plus a
// distributed notification. The file deliberately lives in Application
// Support and NOT in an app group container: macOS 26 gates undeclared
// access to sandboxed apps' group containers behind a TCC consent prompt
// that blocks open() — which froze the app at launch. The sandboxed widget
// reaches this path through a temporary-exception entitlement instead.
import Foundation

enum SharedState {
    static let controlKind = "com.maor.KeepAwakeBar.control"
    static let changedNote = Notification.Name("com.maor.keepawake.changed")

    private static var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeepAwake/state.json")
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
