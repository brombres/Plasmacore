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

    var reply : PlasmacoreMessage?

    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

}
