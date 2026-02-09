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

        setupMenuBar()
        setupPopover()
        startMenuBarUpdates()

        // Request notification permissions
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Takvimi")
            button.title = " ..."
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
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

        // Update icon based on current time of day
        let iconName = timeOfDayIcon(for: viewModel)
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Takvimi")
        button.contentTintColor = nil // Never tint the whole button

        // Apply colored countdown text if enabled
        let coloredCountdown = UserDefaults.standard.object(forKey: "coloredCountdown") as? Bool ?? true
        var useColor: NSColor? = nil

        if coloredCountdown, let next = viewModel.nextPrayer {
            let interval = next.time.timeIntervalSince(Date())
            if interval > 0 && interval <= 1800 { // < 30 min
                useColor = .systemRed
            } else if interval > 0 && interval <= 3600 { // < 1 hour
                useColor = .systemOrange
            }
        }

        if let color = useColor {
            button.title = ""
            button.attributedTitle = NSAttributedString(
                string: " \(text)",
                attributes: [.foregroundColor: color]
            )
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = " \(text)"
        }
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startEventMonitor()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
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
