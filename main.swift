import Cocoa
import IOKit.pwr_mgt
import IOKit.ps
import ServiceManagement

// MacCaffeine: a tiny menu-bar "keep awake" app.
//
// When active it holds the same three IOKit power assertions that `caffeinate -dims` holds:
//   PreventUserIdleDisplaySleep, PreventUserIdleSystemSleep, PreventSystemSleep.
// No root, no child process, no system settings are changed. The kernel drops the assertions
// when this process exits for any reason (quit, crash, kill -9), so the Mac can never be left
// unable to sleep.
//
// Lid closed: macOS only honors these assertions with the lid shut on AC power + external display.
//
// Safety limits: it turns itself off when the battery drops below 20% (on battery power)
// or when the Mac reports critical thermal pressure.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let lowBatteryPercent = 20
    private static let assertionTypes: [CFString] = [
        kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
        kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
        kIOPMAssertionTypePreventSystemSleep as CFString,
    ]

    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var infoItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var assertionIDs: [IOPMAssertionID] = []
    private var autoOffTimer: Timer?
    private var limitTimer: Timer?
    private var endDate: Date?
    private var lastStopReason: String?
    private var active: Bool { !assertionIDs.isEmpty }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.delegate = self
        toggleItem = menu.addItem(withTitle: "Keep awake", action: #selector(toggle), keyEquivalent: "t")
        infoItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(.separator())
        addDuration(to: menu, "Awake for 30 minutes", 30 * 60)
        addDuration(to: menu, "Awake for 1 hour", 60 * 60)
        addDuration(to: menu, "Awake for 2 hours", 2 * 60 * 60)
        addDuration(to: menu, "Awake for 5 hours", 5 * 60 * 60)
        menu.addItem(.separator())
        loginItem = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        updateIcon()

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.checkLimits() }
    }

    private func addDuration(to menu: NSMenu, _ title: String, _ seconds: TimeInterval) {
        let item = NSMenuItem(title: title, action: #selector(activateFor(_:)), keyEquivalent: "")
        item.representedObject = seconds
        item.target = self
        menu.addItem(item)
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.state = active ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if active, let end = endDate {
            infoItem.title = "Awake until " + DateFormatter.localizedString(from: end, dateStyle: .none, timeStyle: .short)
        } else if active {
            infoItem.title = "Awake until you turn it off"
        } else if let reason = lastStopReason {
            infoItem.title = "Stopped: " + reason
        } else {
            infoItem.title = "Sleep allowed"
        }
    }

    @objc private func activateFor(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        start()
        guard active else { return }
        autoOffTimer?.invalidate()
        endDate = Date(timeIntervalSinceNow: seconds)
        autoOffTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.stop(reason: "timer ended")
        }
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
        // macOS can ask the user to approve the login item in System Settings first.
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func toggle() {
        if active { stop(reason: nil) } else { start() }
    }

    @objc private func quit() {
        stop(reason: nil)
        NSApplication.shared.terminate(nil)
    }

    private func start() {
        guard !active else { return }
        lastStopReason = nil
        for type in Self.assertionTypes {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type, IOPMAssertionLevel(kIOPMAssertionLevelOn), "MacCaffeine keep awake" as CFString, &id)
            if result == kIOReturnSuccess { assertionIDs.append(id) }
        }
        if active {
            limitTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.checkLimits()
            }
        } else {
            lastStopReason = "could not create power assertion"
        }
        updateIcon()
    }

    private func stop(reason: String?) {
        for id in assertionIDs { IOPMAssertionRelease(id) }
        assertionIDs.removeAll()
        autoOffTimer?.invalidate()
        autoOffTimer = nil
        limitTimer?.invalidate()
        limitTimer = nil
        endDate = nil
        lastStopReason = reason
        updateIcon()
    }

    private func checkLimits() {
        guard active else { return }
        if ProcessInfo.processInfo.thermalState == .critical {
            stop(reason: "Mac is too hot")
        } else if let percent = batteryPercentOnBattery(), percent < Self.lowBatteryPercent {
            stop(reason: "battery below \(Self.lowBatteryPercent)%")
        }
    }

    /// Battery charge in percent, or nil when running on AC power (or no battery).
    private func batteryPercentOnBattery() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?,
              source == kIOPSBatteryPowerValue,
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for ps in list {
            if let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
               let current = d[kIOPSCurrentCapacityKey] as? Int,
               let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 {
                return current * 100 / max
            }
        }
        return nil
    }

    private func updateIcon() {
        // Filled cup = awake (active), outline cup = normal sleep allowed.
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Keep awake")
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.toolTip = active
            ? "Awake — click the menu to allow sleep"
            : (lastStopReason.map { "Stopped: \($0)" } ?? "Sleep allowed — click the menu to keep awake")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
