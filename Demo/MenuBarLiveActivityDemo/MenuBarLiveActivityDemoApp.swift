//
//  MenuBarLiveActivityDemoApp.swift
//  MenuBarLiveActivityDemo
//
//  Created by Marc Büttner on 09.09.25.
//

import AppKit
import SwiftUI
import MenuBarLiveActivity

@main
struct MenuBarLiveActivityDemoApp: App {

    private let activity: MenuBarLiveActivity

    init() {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings", action: nil, keyEquivalent: ",")
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        menu.addItem(quit)

        let icon = NSImage(systemSymbolName: "livephoto", accessibilityDescription: nil)!

        self.activity = MenuBarLiveActivity(icon: icon, menu: menu)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(activity: activity)
        }
    }
}
