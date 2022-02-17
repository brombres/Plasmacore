//
//  PlasmacoreView.swift
//  PlasmacoreStudio
//
//  Created by Abe Pralle on 3/27/16.
//
import Metal
import MetalKit
import simd

/*
import Cocoa
import AppKit

import GLKit
*/

class PlasmacoreView : MTKView
{

  var isConfigured = false
  var keyModifierFlags:UInt = 0

  //required init(coder: NSCoder)
  //{
  //  super.init( coder:coder )
  //}

  //override init( frame:CGRect, device:MTLDevice? )
  //{
  //  super.init( frame:frame, device:device )
  //}

  override var acceptsFirstResponder: Bool { return true }

  override func becomeFirstResponder() -> Bool
  {
    if ( !super.becomeFirstResponder() ) { return false }

    if let window = window
    {
      window.acceptsMouseMovedEvents = true
    }

    let m = PlasmacoreMessage( "Display.on_focus_gained" )
    m.writeInt32X( 0 )  // display_id: 0
    m.send()
    return true
  }

  override func flagsChanged( with event:NSEvent )
  {
    let newFlags = event.modifierFlags.rawValue
    let modified = keyModifierFlags ^ newFlags
    handleModifiedKey( modified:modified, mask:NSEvent.ModifierFlags.capsLock.rawValue, keycode:Keyboard.Keycode.CAPS_LOCK )

    handleModifiedKey( modified:modified, mask:2, keycode:Keyboard.Keycode.LEFT_SHIFT )
    handleModifiedKey( modified:modified, mask:4, keycode:Keyboard.Keycode.RIGHT_SHIFT )

    handleModifiedKey( modified:modified, mask:1,      keycode:Keyboard.Keycode.LEFT_CONTROL )
    handleModifiedKey( modified:modified, mask:0x2000, keycode:Keyboard.Keycode.RIGHT_CONTROL )

    handleModifiedKey( modified:modified, mask:0x20, keycode:Keyboard.Keycode.LEFT_ALT )
    handleModifiedKey( modified:modified, mask:0x40, keycode:Keyboard.Keycode.RIGHT_ALT )

    handleModifiedKey( modified:modified, mask:0x08, keycode:Keyboard.Keycode.LEFT_OS )
    handleModifiedKey( modified:modified, mask:0x10, keycode:Keyboard.Keycode.RIGHT_OS )

    handleModifiedKey( modified:modified, mask:NSEvent.ModifierFlags.numericPad.rawValue, keycode:Keyboard.Keycode.NUMPAD_ENTER )

    keyModifierFlags = newFlags
  }

  func handleModifiedKey( modified:UInt, mask:UInt, keycode:Int )
  {
    if ((modified & mask) == mask)
    {
      let m = PlasmacoreMessage( "Display.on_key_event" )
      m.writeInt32X( 0 )  // display_id
      m.writeLogical( (keyModifierFlags & mask) == 0 )  // is_press: true/false
      m.writeInt32X( keycode )
      m.writeInt32X( 0 )   // syscode
      m.writeLogical( false ) // is_repeat
      m.send()
    }
  }

  override func keyDown( with event:NSEvent )
  {
    let syscode = Int( event.keyCode & 0x7f )
    let keycode = Keyboard.syscodeToKeycode[ syscode ]
    do
    {
      let m = PlasmacoreMessage( "Display.on_key_event" )
      m.writeInt32X( 0 )       // display_id
      m.writeLogical( true )   // is_press: true
      m.writeInt32X( keycode )
      m.writeInt32X( syscode )
      m.writeLogical( event.isARepeat )
      m.send()
    }

    guard let characters = event.characters else { return }
    if (characters.isEmpty) { return }
    let unicode = Int( characters.unicodeScalars[ characters.unicodeScalars.startIndex ].value )

    // Don't send unicode 0..31 or 127 as a TextEvent
    if (characters.count > 1 || (characters.count == 1 && unicode >= 32 && unicode != 127))
    {
      let m = PlasmacoreMessage( "Display.on_text_event" )
      m.writeInt32X( 0 )        // display_id
      m.writeInt32X( unicode )
      m.writeString( characters )
      m.send()
    }
  }

  override func keyUp( with event:NSEvent )
  {
    let syscode = Int( event.keyCode & 0x7f )
    let keycode = Keyboard.syscodeToKeycode[ syscode ]

    let m = PlasmacoreMessage( "Display.on_key_event" )
    m.writeInt32X( 0 )        // display_id
    m.writeLogical( false )   // is_press
    m.writeInt32X( keycode )
    m.writeInt32X( syscode )
    m.writeLogical( false )   // is_repeat
    m.send()
  }

  override func mouseDown( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from:nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 1 )        // type: 1 = press
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 0 )        // index: 0
    m.send()
  }

  override func mouseDragged( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 0 )        // type: 0 = move
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 0 )        // index: 0
    m.send()
  }

  override func mouseMoved( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 0 )        // type: 0 = move
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 0 )        // index: 0
    m.send()
  }

  override func mouseUp( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 2 )        // type: 2 = release
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 0 )        // index: 0
    m.send()
  }

  override func rightMouseDown( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 1 )        // type: 1 = press
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 1 )        // index: 1
    m.send()
  }

  override func rightMouseDragged( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 0 )        // type: 0 = move
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 0 )        // index:0
    m.send()
  }

  override func rightMouseUp( with event:NSEvent )
  {
    let point = convert( event.locationInWindow, from: nil )

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )

    let m = PlasmacoreMessage( "Display.on_pointer_event" )
    m.writeInt32X( 0 )        // display_id: 0
    m.writeInt32X( 2 )        // type: 2 = release
    m.writeInt32X( Int(point.x * scale) )
    m.writeInt32X( Int((bounds.size.height - point.y) * scale) )
    m.writeInt32X( 1 )        // index: 1
    m.send()
  }

  override func scrollWheel( with event:NSEvent )
  {
    var dx = event.deltaX
    var dy = event.deltaY

    let scale = Double( NSScreen.main?.backingScaleFactor ?? CGFloat(1.0) )
    let inProgress = (event.phase != NSEvent.Phase.ended && event.momentumPhase != NSEvent.Phase.ended)

    if (dx >= -0.0001 && dx <= 0.0001){ dx = 0 }
    if (dy >= -0.0001 && dy <= 0.0001){ dy = 0 }

    if (!inProgress || dx != 0 || dy != 0)
    {
      let m = PlasmacoreMessage( "Display.on_scroll_event" )
      m.writeInt32X( 0 )        // display_id: 0
      m.writeReal64( Double(dx)*scale )
      m.writeReal64( Double(dy)*scale )
      m.writeLogical( event.hasPreciseScrollingDeltas )  // is_precise
      m.writeLogical( inProgress )                       // in_progress
      m.writeLogical( event.momentumPhase != [] )        // is_momentum
      m.send()
    }
  }
}

