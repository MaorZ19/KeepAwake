// Control Center toggle for KeepAwake (macOS 26+ WidgetKit control).
// The toggle flips the shared state; the menu bar app owns the actual
// caffeinate process and reacts via the distributed notification.
import AppKit
import WidgetKit
import SwiftUI
import AppIntents

@main
struct KeepAwakeControlBundle: WidgetBundle {
    var body: some Widget {
        KeepAwakeControl()
    }
}

struct KeepAwakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SharedState.controlKind, provider: Provider()) { isOn in
            ControlWidgetToggle("Keep Awake", isOn: isOn, action: ToggleKeepAwakeIntent()) { on in
                Label(on ? "On" : "Off",
                      systemImage: on ? "cup.and.saucer.fill" : "cup.and.saucer")
            }
        }
        .displayName("Keep Awake")
        .description("Keeps the Mac awake (caffeinate)")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { true }
        func currentValue() async throws -> Bool { SharedState.isEnabled }
    }
}

struct ToggleKeepAwakeIntent: SetValueIntent {
    static var title: LocalizedStringResource { "Toggle Keep Awake" }

    @Parameter(title: "Keep Awake")
    var value: Bool

    func perform() async throws -> some IntentResult {
        SharedState.setEnabled(value)
        if value { launchAppIfNeeded() }
        return .result()
    }

    // caffeinate is owned by the menu bar app — if it isn't running (user
    // quit it), turning the control on must bring it back.
    private func launchAppIfNeeded() {
        guard NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.maor.KeepAwakeBar").isEmpty else { return }
        let ws = NSWorkspace.shared
        let url = ws.urlForApplication(withBundleIdentifier: "com.maor.KeepAwakeBar")
            ?? URL(fileURLWithPath: "/Applications/KeepAwake.app")
        ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
