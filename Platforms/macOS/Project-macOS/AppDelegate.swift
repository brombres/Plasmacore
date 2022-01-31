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
      Plasmacore.singleton.setMessageListener( type:"Log", listener:
        {
          (m:PlasmacoreMessage) in
            print( "LOG: " + m.readString() )
        }
      )
      Plasmacore.singleton.setMessageListener( type:"Marco", listener:
        {
          (m:PlasmacoreMessage) in
            print( "Marco!" )
            self.reply = m.reply()
        }
      )

      Plasmacore.singleton.launch()

      PlasmacoreMessage( type:"NotifyOnExit" ).sendRSVP( callback:
        {
          (m:PlasmacoreMessage) in
            print("About to exit!")
        }
      )
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
      if let reply = PlasmacoreMessage( type:"ShouldTerminate" ).send()
      {
        print( "terminate:" )
        if (reply.readLogical()) { print("true") }
        else                     { print("false") }
      }

      if let reply = self.reply
      {
        reply.writeString( "Polo!" )
          reply.send()
      }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

}
