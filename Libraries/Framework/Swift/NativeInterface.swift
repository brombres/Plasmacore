#if os(OSX)
import Cocoa
#else
import Foundation
#endif

import AVFoundation

@objc class NativeInterface : NSObject
{
  @objc class func receiveMessage( _ data:UnsafePointer<UInt8>, count:Int )->NSData?
  {
    let m = PlasmacoreMessage( data:Array(UnsafeBufferPointer(start:data,count:count)) )

    m.defer_reply = true
    Plasmacore.singleton.dispatch( m )
    m.defer_reply = false

    if let reply = m._reply
    {
      if (reply.send_requested)
      {
        return NSData( bytes:reply.data, length:reply.data.count )
      }
      else
      {
        reply.defer_reply = false
        return nil
      }
    }
    else
    {
      return nil
    }
  }
}

