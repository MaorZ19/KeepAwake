// KeepAwake — menu bar toggle for the keep-the-Mac-awake mode.
// Left-click the cup icon to toggle, right-click for menu. State is shared
// with the Control Center toggle (control.swift) via SharedState; this app
// is the only process that owns the caffeinate child.
import AppKit
import ServiceManagement
#if !NO_CONTROL_CENTER
import WidgetKit
#endif

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var caffeinate: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // One-time: take over the old agent's run-at-login role. Can be turned
        // off later from the right-click menu.
        if !UserDefaults.standard.bool(forKey: "didRegisterLoginItem") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didRegisterLoginItem")
        }

        // The Control Center toggle announces its changes here.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(stateChangedExternally),
            name: SharedState.changedNote, object: nil)

        applyState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopCaffeinate()
    }

    // MARK: - State

    @objc private func stateChangedExternally() {
        DispatchQueue.main.async { self.applyState() }
    }

    /// Idempotent: makes the caffeinate process and icon match SharedState.
    private func applyState() {
        if SharedState.isEnabled { startCaffeinate() } else { stopCaffeinate() }
        updateIcon()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        SharedState.setEnabled(!SharedState.isEnabled)
        applyState()
        #if !NO_CONTROL_CENTER
        if #available(macOS 26.0, *) {
            ControlCenter.shared.reloadControls(ofKind: SharedState.controlKind)
        }
        #endif
    }

    private func updateIcon() {
        let enabled = SharedState.isEnabled
        let desc = enabled ? "Keep awake on" : "Keep awake off"
        // Steaming cup (macOS 14+), plain cup as fallback on macOS 13.
        let image = NSImage(systemSymbolName: enabled ? "cup.and.heat.waves.fill" : "cup.and.heat.waves",
                            accessibilityDescription: desc)
            ?? NSImage(systemSymbolName: enabled ? "cup.and.saucer.fill" : "cup.and.saucer",
                       accessibilityDescription: desc)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !enabled
        statusItem.button?.toolTip = enabled
            ? "KeepAwake: המק לא יירדם — קליק לכיבוי"
            : "KeepAwake: שינה רגילה — קליק להפעלה"
    }

    // MARK: - caffeinate process

    private func startCaffeinate() {
        guard caffeinate == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // Same flags as the old agent; -w makes caffeinate exit if this app
        // dies without cleaning up (force-quit, crash).
        p.arguments = ["-ims", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        // KeepAlive parity: if caffeinate is killed externally while the mode
        // is on, restart it. Intentional stops detach this handler first.
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self, self.caffeinate === proc else { return }
                self.caffeinate = nil
                if SharedState.isEnabled { self.startCaffeinate() }
            }
        }
        do {
            try p.run()
            caffeinate = p
        } catch {
            NSLog("KeepAwake: failed to start caffeinate: \(error)")
        }
    }

    private func stopCaffeinate() {
        guard let p = caffeinate else { return }
        caffeinate = nil
        p.terminationHandler = nil
        p.terminate()
    }

    // MARK: - Right-click menu

    private func showMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let enabled = SharedState.isEnabled
        let state = NSMenuItem(title: enabled ? "Keep Awake: On" : "Keep Awake: Off",
                               action: #selector(toggle), keyEquivalent: "")
        state.target = self
        state.state = enabled ? .on : .off
        menu.addItem(state)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Start at Login",
                               action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit KeepAwake", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("KeepAwake: login item change failed: \(error)")
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
