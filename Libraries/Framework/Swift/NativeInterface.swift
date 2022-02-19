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
  @discardableResult
  @objc class func createTexture( _ textureID:Int, _ width:Int, _ height:Int )->MTLTexture?
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
        return texture
      }
    }
    catch
    {
    }
    return nil
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

  @objc class func updateTexture( _ textureID:Int, _ width:Int, _ height:Int, _ data:UnsafePointer<UInt8> )
  {
    do
    {
      var texture = Plasmacore.singleton.textures[textureID]
      if (texture?.width != width || texture?.height != height)
      {
        texture = nil
      }

      if (texture == nil)
      {
        texture = createTexture( textureID, width, height )
        if let texture = texture
        {
          Plasmacore.singleton.textures[textureID] = texture
        }
      }

      if let texture = texture
      {
        texture.replace( region:MTLRegionMake2D(0,0,width,height), mipmapLevel:0, withBytes:data, bytesPerRow:width*4 )
      }
    }
    catch
    {
    }
  }

}

