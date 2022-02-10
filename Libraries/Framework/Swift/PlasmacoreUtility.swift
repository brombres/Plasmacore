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

  class func loadTexture( _ filename:String ) throws -> MTLTexture
  {
    guard let device = Plasmacore.singleton.currentMetalDevice else { throw PlasmacoreError.runtimeError("loadTexture: no device") }
    let textureLoader = MTKTextureLoader( device:device )

    let textureLoaderOptions =
    [
      MTKTextureLoader.Option.textureUsage: NSNumber( value:MTLTextureUsage.shaderRead.rawValue ),
      MTKTextureLoader.Option.textureStorageMode: NSNumber( value:MTLStorageMode.`private`.rawValue )
    ]
      
      return try textureLoader.newTexture(
        URL:URL(fileURLWithPath:filename),
        options: textureLoaderOptions
      )
  }
}

