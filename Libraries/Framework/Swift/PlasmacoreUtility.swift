#if os(OSX)
import Cocoa
#else
import Foundation
#endif

import AVFoundation

import Metal
import MetalKit

class PlasmacoreUtility
{
  class func currentTime()->Double
  {
    var darwin_time : timeval = timeval( tv_sec:0, tv_usec:0 )
    gettimeofday( &darwin_time, nil )
    return (Double(darwin_time.tv_sec)) + (Double(darwin_time.tv_usec) / 1000000)
  }

  class func lastIndexOf( _ st:String, lookFor:String )->Int?
  {
    if let r = st.range( of: lookFor, options:.backwards )
    {
      return st.distance(from: st.startIndex, to: r.lowerBound)
    }

    return nil
  }

  class func loadTexture( _ textureID:Int, _ filepath:String )
  {
    do
    {
      try PlasmacoreUtility.loadTexture( filepath,
      {
        (texture:MTLTexture?,err:Error?) in
          let m = PlasmacoreMessage( "Texture.on_load" ).writeInt32X( textureID )
          if let texture = texture
          {
            Plasmacore.singleton.textures[textureID] = texture
            m.writeLogical( true )
            m.writeInt32X( texture.width )
            m.writeInt32X( texture.height )
          }
          else
          {
            m.writeLogical(false)
          }
          m.send()
      } )
    }
    catch
    {
      let m = PlasmacoreMessage( "Texture.on_load" ).writeInt32X( textureID )
      m.writeLogical(false)
      m.send()
    }
  }

  //class func loadBitmap( _ filepath:String )->CGImage?
  //{
  //  if let nsImage = NSImage( byReferencingFile:filepath )
  //  {
  //    if let cgImage = nsImage.cgImage( forProposedRect:nil, context:nil, hints:nil )
  //    {
  //      return cgImage
  //    }
  //  }
  //  return nil
  //}

  class func loadTexture( _ filepath:String, _ callback:@escaping MTKTextureLoader.Callback ) throws
  {
    guard let device = Plasmacore.singleton.currentMetalDevice else { throw PlasmacoreError.runtimeError("loadTexture: no device") }
    let textureLoader = MTKTextureLoader( device:device )

    let textureLoaderOptions =
    [
      MTKTextureLoader.Option.SRGB: true,
      MTKTextureLoader.Option.textureUsage: NSNumber( value:MTLTextureUsage.shaderRead.rawValue ),
      MTKTextureLoader.Option.textureStorageMode: NSNumber( value:MTLStorageMode.`private`.rawValue )
    ]

    textureLoader.newTexture(
      URL:URL(fileURLWithPath:filepath),
      options: textureLoaderOptions,
      completionHandler:callback
    )
  }
}

