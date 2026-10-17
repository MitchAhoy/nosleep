import AppKit
import IOKit.pwr_mgt
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let bundleID = "com.mitch.nosleep"
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var isOn: Bool { assertionID != 0 }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only ever run one copy (e.g. if both the login item and the LaunchAgent fire).
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
        registerLoginItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        setNoSleep(false)
    }

    // MARK: - Clicks

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isRightClick {
            showMenu()
        } else {
            setNoSleep(!isOn)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: isOn ? "No Sleep: On" : "No Sleep: Off", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NoSleep", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Attach the menu only for this click so left-click keeps toggling.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        setNoSleep(false)
        NSApp.terminate(nil)
    }

    // MARK: - Power assertion

    private func setNoSleep(_ on: Bool) {
        if on, !isOn {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NoSleep: keeping Mac and display awake" as CFString,
                &id)
            if result == kIOReturnSuccess { assertionID = id }
        } else if !on, isOn {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let name = isOn ? "cup.and.saucer.fill" : "cup.and.saucer"
        let tip = isOn ? "No Sleep: On" : "No Sleep: Off"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: tip)
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
    }

    // MARK: - Launch at login

    private func registerLoginItem() {
        let service = SMAppService.mainApp
        if service.status != .enabled {
            do {
                try service.register()
            } catch {
                NSLog("NoSleep: SMAppService register failed: \(error)")
            }
        }
        if service.status == .enabled {
            removeLaunchAgent()
        } else {
            NSLog("NoSleep: SMAppService status \(service.status.rawValue); using LaunchAgent fallback")
            installLaunchAgent()
        }
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(bundleID).plist")
    }

    private func installLaunchAgent() {
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": bundleID,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(
                at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentURL, options: .atomic)
        } catch {
            NSLog("NoSleep: failed to write LaunchAgent: \(error)")
        }
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentURL)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
