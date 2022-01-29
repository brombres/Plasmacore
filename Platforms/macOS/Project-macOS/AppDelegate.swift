//
//  AppDelegate.swift
//  Project-macOS
//
//  Created by Abe Pralle on 1/28/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        RogueInterface_configure()
        RogueInterface_launch()
    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}
