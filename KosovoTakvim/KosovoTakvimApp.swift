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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Prevent macOS from auto-terminating this menu bar app
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app running")
        ProcessInfo.processInfo.disableSuddenTermination()

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
            button.action = #selector(handleStatusBarClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
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

        // Build combined icon + text attributed string for proper alignment
        let result = NSMutableAttributedString()

        // Icon as text attachment
        let font = NSFont.menuBarFont(ofSize: 0)
        if let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Takvimi") {
            let config = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular)
            let configuredImage = symbolImage.withSymbolConfiguration(config) ?? symbolImage
            let attachment = NSTextAttachment()
            attachment.image = configuredImage
            let iconHeight = font.capHeight
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - iconHeight) / 2, width: iconHeight, height: iconHeight)
            result.append(NSAttributedString(attachment: attachment))
        }

        // Space + text
        let textAttrs: [NSAttributedString.Key: Any]
        if let color = textColor {
            textAttrs = [.font: font, .foregroundColor: color, .baselineOffset: 0]
        } else {
            textAttrs = [.font: font, .baselineOffset: 0]
        }
        result.append(NSAttributedString(string: " \(text)", attributes: textAttrs))

        button.image = nil
        button.title = ""
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

    @objc private func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            closePopover()
        } else {
            viewModel?.updateCurrentTime()
            viewModel?.startPopoverUpdates()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startEventMonitor()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Rifresko", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Dil", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshAction() {
        viewModel?.refreshPrayerTimes()
        updateMenuBarText()
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
        updateTimer?.invalidate()
        stopEventMonitor()
    }
}
