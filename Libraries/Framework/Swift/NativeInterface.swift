#if os(OSX)
import Cocoa
#else
import Foundation
#endif

import AVFoundation
import Metal
import MetalKit

@objc class NativeInterface : NSObject
{
  @objc class func createTextureFromBitmap( _ textureID:Int, _ data:UnsafePointer<UInt8>, _ width:Int, _ height:Int )
  {
    do
    {
      guard let device = Plasmacore.singleton.currentMetalDevice else
          { throw PlasmacoreError.runtimeError("createTextureFromBitmap: no device") }
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat:MTLPixelFormat.rgba8Unorm_srgb, width:width, height:height, mipmapped:false )
      if let texture = device.makeTexture( descriptor:descriptor )
      {
        Plasmacore.singleton.textures[textureID] = texture
        texture.replace( region:MTLRegionMake2D(0,0,width,height), mipmapLevel:0, withBytes:data, bytesPerRow:width*4 )
      }
    }
    catch
    {
    }
  }

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

