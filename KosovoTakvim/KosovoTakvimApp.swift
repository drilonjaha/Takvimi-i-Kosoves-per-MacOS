import SwiftUI
import AppKit

@main
struct KosovoTakvimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: MenuBarViewModel?
    private var updateTimer: Timer?
    private var eventMonitor: Any?
    private var rightClickMonitor: Any?
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Keep app alive — beginActivity is the modern API that reliably prevents
        // macOS from auto-terminating accessory/menu-bar apps with no visible windows.
        // The old disableAutomaticTermination/disableSuddenTermination calls are
        // unreliable with SwiftUI's App lifecycle.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .suddenTerminationDisabled, .automaticTerminationDisabled],
            reason: "Menu bar prayer time countdown must stay active"
        )

        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()

        // Request notification permissions
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = " ..."
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Monitor right-clicks on the status bar button
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self = self,
                  let button = self.statusItem?.button,
                  let window = button.window,
                  window == event.window else {
                return event
            }
            self.showContextMenu()
            return nil // consume the event
        }
    }

    private func setupPopover() {
        viewModel = MenuBarViewModel()

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 400)
        popover?.behavior = .transient
        popover?.animates = true

        if let viewModel = viewModel {
            popover?.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))

            // Update menu bar when prayer data loads or city changes (targeted, no loop)
            viewModel.onPrayerDataChanged = { [weak self] in
                self?.updateMenuBarText()
            }
        }
    }

    private func startMenuBarUpdates() {
        updateMenuBarText()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateMenuBarText()
        }
    }

    private func updateMenuBarText() {
        guard let button = statusItem?.button, let viewModel = viewModel else { return }

        // Refresh current time and next prayer before reading state
        viewModel.updateCurrentTime()

        let text = viewModel.menuBarText
        let iconName = timeOfDayIcon(for: viewModel)

        // Determine text color
        let coloredCountdown = UserDefaults.standard.object(forKey: "coloredCountdown") as? Bool ?? true
        var textColor: NSColor? = nil

        if coloredCountdown, let next = viewModel.nextPrayer {
            let interval = next.time.timeIntervalSince(Date())
            if interval > 0 && interval <= 1800 {
                textColor = .systemRed
            } else if interval > 0 && interval <= 3600 {
                textColor = .systemOrange
            }
        }

        let font = NSFont.menuBarFont(ofSize: 0)
        let result = NSMutableAttributedString()

        // Render SF Symbol as text attachment with precise vertical centering
        let iconSize = font.pointSize * 0.9
        if let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Takvimi") {
            var config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            if let color = textColor {
                config = config.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            }
            let configured = symbolImage.withSymbolConfiguration(config) ?? symbolImage
            if textColor == nil { configured.isTemplate = true }

            let attachment = NSTextAttachment()
            attachment.image = configured
            // Center icon vertically: align middle of icon with middle of cap height
            let yOffset = round((font.capHeight - iconSize) / 2.0) + 1
            attachment.bounds = CGRect(x: 0, y: yOffset, width: iconSize, height: iconSize)
            result.append(NSAttributedString(attachment: attachment))
        }

        // Space + text
        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if let color = textColor {
            attrs[.foregroundColor] = color
        }
        result.append(NSAttributedString(string: " \(text)", attributes: attrs))

        button.image = nil
        button.imagePosition = .noImage
        button.attributedTitle = result
    }

    private func timeOfDayIcon(for viewModel: MenuBarViewModel) -> String {
        guard let times = viewModel.prayerTimes else { return "moon.stars" }
        let now = Date()

        // Determine which prayer period we're in
        if now < times.imsak {
            return "moon.stars"      // Night (before Imsak)
        } else if now < times.sunrise {
            return "sunrise"         // Pre-dawn / Fajr period
        } else if now < times.dhuhr {
            return "sun.max"         // Morning
        } else if now < times.asr {
            return "sun.max.fill"    // Midday / early afternoon
        } else if now < times.maghrib {
            return "sun.min"         // Late afternoon
        } else if now < times.isha {
            return "sunset"          // Evening
        } else {
            return "moon.stars"      // Night (after Isha)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            closePopover()
        } else {
            viewModel?.updateCurrentTime()
            viewModel?.startPopoverUpdates()
            Task { await viewModel?.checkForUpdate() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startEventMonitor()
        }
    }

    private func showContextMenu() {
        // Close popover first if open
        if popover?.isShown == true {
            closePopover()
        }

        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Rifresko", action: #selector(refreshAction), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: "Kontrollo përditësimet", action: #selector(checkUpdateAction), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Dil", action: #selector(quitAction), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        }
    }

    @objc private func refreshAction() {
        viewModel?.refreshPrayerTimes()
        updateMenuBarText()
    }

    @objc private func checkUpdateAction() {
        Task {
            await viewModel?.checkForUpdate()
            if let vm = viewModel, vm.updateAvailable {
                vm.openUpdate()
            }
        }
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    private func closePopover() {
        popover?.performClose(nil)
        viewModel?.stopPopoverUpdates()
        stopEventMonitor()
    }

    private func startEventMonitor() {
        // Monitor for clicks outside the popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        updateTimer?.invalidate()
        stopEventMonitor()
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
