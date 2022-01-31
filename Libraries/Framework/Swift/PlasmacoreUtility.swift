#if os(OSX)
import Cocoa
#else
import Foundation
#endif

import AVFoundation

class PlasmacoreUtility
{
  static func currentTime()->Double
  {
    var darwin_time : timeval = timeval( tv_sec:0, tv_usec:0 )
    gettimeofday( &darwin_time, nil )
    return (Double(darwin_time.tv_sec)) + (Double(darwin_time.tv_usec) / 1000000)
  }

  static func lastIndexOf( _ st:String, lookFor:String )->Int?
  {
    if let r = st.range( of: lookFor, options:.backwards )
    {
      return st.distance(from: st.startIndex, to: r.lowerBound)
    }

    return nil
  }
}

