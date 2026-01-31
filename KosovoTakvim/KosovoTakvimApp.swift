import SwiftUI
import AppKit
import Combine

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
    private var cancellables = Set<AnyCancellable>()

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

            // Observe viewModel changes to update menu bar immediately
            viewModel.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateMenuBarText()
                }
                .store(in: &cancellables)
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

        let text = viewModel.menuBarText
        button.title = " \(text)"

        // Update icon based on proximity to next prayer
        if let next = viewModel.nextPrayer {
            let interval = next.time.timeIntervalSince(Date())
            if interval <= 300 { // 5 minutes
                button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "Prayer soon")
                button.contentTintColor = .systemOrange
            } else if interval <= 900 { // 15 minutes
                button.image = NSImage(systemSymbolName: "bell", accessibilityDescription: "Prayer approaching")
                button.contentTintColor = .systemYellow
            } else {
                button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Takvimi")
                button.contentTintColor = nil
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            viewModel?.updateCurrentTime()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Make popover active
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }
}
