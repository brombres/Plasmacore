#if os(OSX)
  import Cocoa
#endif

// High-low byte order for all multi-byte values.
//
// Message
//   timestamp       : Real64
//   message_id      : Int32X                  # serial number (always present, only needed when reply expected)
//   type_name_count : Int32X                  # 0 indicates a reply
//   type_name       : Int32X[type_name_count]
//   arbitrary_data  : Byte[...]

class PlasmacoreMessage
{
  static var next_message_id = 1

  var timestamp  : Double
  var message_id = 0

  var data       = [UInt8]()
  var entries    = [String:Int]()
  var position   = 0

  var _reply:PlasmacoreMessage? = nil

  convenience init( type:String )
  {
    self.init( type:type, message_id:PlasmacoreMessage.next_message_id )
    PlasmacoreMessage.next_message_id += 1
  }

  convenience init( data:[UInt8] )
  {
    self.init()
    self.data  = data
    timestamp  = readReal64()
    message_id = readInt32X()
  }

  convenience init( type:String, message_id:Int )
  {
    self.init()
    self.message_id = message_id
    writeReal64( timestamp )
    writeInt32X( message_id )
    writeString( type )
  }

  convenience init( reply_to_message_id:Int )
  {
    self.init( type: "", message_id: reply_to_message_id )
  }

  init()
  {
    timestamp = PlasmacoreMessage.currentTime()
  }

  func isType( name:String )->Bool
  {
    position = 8 // just past timestamp
    message_id = readInt32X()

    let characters = name.unicodeScalars
    let count = readInt32X()
    if (characters.count != count)
    {
      return false
    }

    for ch in characters
    {
      if (Int(ch.value) != readInt32X())
      {
        return false
      }
    }
    return true
  }

  func reply()->PlasmacoreMessage
  {
    if (_reply == nil)
    {
      _reply = PlasmacoreMessage( reply_to_message_id:message_id )
    }
    return _reply!
  }

  //func post_rsvp( _ callback:@escaping ((PlasmacoreMessage)->Void) )

  @discardableResult
  func send()->PlasmacoreMessage?
  {
    if let result_data = RogueInterface_send_message( data, Int32(data.count) )
    {
      return PlasmacoreMessage( data:[UInt8](result_data) )
    }
    else
    {
      return nil
    }
  }

  @discardableResult
  func readByte()->Int
  {
    if (position >= data.count) { return 0 }
    let result = Int( data[position] )
    position += 1
    return result
  }

  func readInt32()->Int
  {
    var result = readByte() << 24
    result |= readByte()    << 16
    result |= readByte()    <<  8
    return result | readByte()
  }

  func readInt32X()->Int
  {
    // Reads a variable-length encoded value that is stored in 1..5 bytes.
    // Encoded values are treated as signed.
    //
    // - If the first two bits are not "10" then the first byte is cast to
    //   a signed integer value and returned. This allows for the range
    //   -64..127 using the following bit patterns:
    //
    //     0xxxxxxx    0 .. 127
    //     11xxxxxx  -64 ..  -1
    //
    // - If the first two bits are "10" then the data has been encoded
    //   in the next 6 bits as well as any number of following bytes,
    //   (up to 4 additional) using 7 data bits per byte with an MSBit
    //   of 0 representing a halt or 1 a continuation. The next bit after
    //   the leading 10 in the first byte is treated as negative magnitude.
    //
    //     10xxxxxx 0yyyyyyy            (13-bit number xxxxxxyyyyyyy)
    //     10xxxxxx 1yyyyyyy 0zzzzzzz   (20-bit number xxxxxxyyyyyyyzzzzzzz)
    //     etc.
    let b = readByte()
    if ((b & 0xc0) != 0x80)
    {
      if ((b & 0x80) != 0)
      {
        return b - 256
      }
      else
      {
        return b
      }
    }

    var result = (b & 0b0011_1111)  //  0..63  (positive)
    if (result >= 32)
    {
      result -= 64  // -64..63 (negative)
    }

    for _ in 1...4 // up to 4 more bytes
    {
      let next = readByte()
      result = (result << 7) | (next & 0b0111_1111)
      if ((next & 0b1000_0000) != 0)
      {
        return result
      }
    }

    return result
  }

  func readReal64()->Double
  {
    var n = UInt64( readInt32() ) << 32
    n = n | UInt64( UInt32(readInt32()) )
    return Double(bitPattern:n)
  }

  func readString()->String
  {
    let count  = readInt32X()
    var characters = "".unicodeScalars
    if (count > 0)
    {
      characters.reserveCapacity( count )
      for _ in 1...count
      {
        let n = readInt32X()
        if let ch = UnicodeScalar( n )
        {
          characters.append( ch )
        }
      }
    }

    return String(characters)
  }

  static func currentTime()->Double
  {
    var darwin_time : timeval = timeval( tv_sec:0, tv_usec:0 )
    gettimeofday( &darwin_time, nil )
    return (Double(darwin_time.tv_sec)) + (Double(darwin_time.tv_usec) / 1000000)
  }

  func writeByte( _ value:Int )
  {
    if (position >= data.count)
    {
      data.append( UInt8(value&255) )
    }
    else
    {
      data[ position ] = UInt8( value )
    }
    position += 1
  }

  func writeInt32( _ value:Int )
  {
    writeByte( value >> 24 )
    writeByte( value >> 16 )
    writeByte( value >> 8  )
    writeByte( value )
  }

  func writeInt32X( _ value:Int )
  {
    // Writes a variable-length encoded value that is stored in 1..5 bytes.
    // See readInt32X for encoding details
    if (value >= -64 && value < 128)
    {
      data.append( UInt8(value&255) )
    }
    else
    {
      var extra_bytes = 1
      var shift = 7
      var min = -0x1000
      var max =  0x0FFF
      for _ in 1...3
      {
        if (value >= min && value <= max)
        {
          break;
        }
        extra_bytes += 1
        shift += 7
        min =  min << 7
        max = (max << 7) | 0xFF
      }

      writeByte( 0b10_000000 | ((value>>shift)&0b11_1111) )

      if (extra_bytes > 1)
      {
        for _ in 2...extra_bytes
        {
          shift -= 7
          writeByte( 0b1000_0000 | ((value>>shift) & 0b0111_1111) )
        }
      }

      shift -= 7
      writeByte( (value>>shift) & 0b0111_1111 )
    }
  }

  func writeReal64( _ value:Double )
  {
    let bits = value.bitPattern
    writeInt32( Int((bits>>32)&0xFFFFffff) )
    writeInt32( Int(bits&0xFFFFffff) )
  }

  func writeString( _ value:String )
  {
    let characters = value.unicodeScalars
    writeInt32X( characters.count )
    for ch in characters
    {
      writeInt32X( Int(ch.value) )
    }
  }
}

