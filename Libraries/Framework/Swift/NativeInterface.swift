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
    NSLog( "TODO: NativeInterface.receiveMessage" )
    /*
    let m = PlasmacoreMessage( data:Array(UnsafeBufferPointer(start:data,count:count)) )
    Plasmacore.singleton.dispatch( m )
    if let reply = m._reply
    {
      reply._block_transmission = false
      return NSData( bytes:reply.data, length:reply.data.count )
    }
    else
    {
      return nil
    }
    */
    return nil
  }
}

