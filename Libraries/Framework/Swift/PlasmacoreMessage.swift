#if os(OSX)
  import Cocoa
#endif

// High-low byte order for all multi-byte values.
//
// Message
//   message_id      : Int32X                  # serial number (always present, only needed when reply expected)
//   type_name_count : Int32X                  # 0 indicates a reply
//   type_name       : Int32X[type_name_count]
//   arbitrary_data  : Byte[...]

class PlasmacoreMessage
{
  static var next_message_id = 1

  var message_id     = 0
  var type           = ""

  var data           = [UInt8]()
  var entries        = [String:Int]()
  var position       = 0

  // This variable pair is used to prevent a reply from being sent (with send()) while
  // in the original callback so that it can be sent back as a synchronous response.
  var defer_reply    = false
  var send_requested = false

  var _reply:PlasmacoreMessage? = nil

  convenience init( _ type:String )
  {
    self.init( type:type, message_id:PlasmacoreMessage.next_message_id )
    PlasmacoreMessage.next_message_id += 1
  }

  convenience init( data:[UInt8] )
  {
    self.init()
    self.data  = data
    message_id = readInt32X()
    type       = readString()
  }

  convenience init( type:String, message_id:Int )
  {
    self.init()
    self.message_id = message_id
    self.type = type
    writeInt32X( message_id )
    writeString( type )
  }

  convenience init( reply_to_message_id:Int, defer_reply:Bool )
  {
    self.init( type:"", message_id: reply_to_message_id )
    self.defer_reply = defer_reply
  }

  init()
  {
  }

  func reply()->PlasmacoreMessage
  {
    if (_reply == nil)
    {
      _reply = PlasmacoreMessage( reply_to_message_id:message_id, defer_reply:self.defer_reply )
    }
    return _reply!
  }

  @discardableResult
  func send()->PlasmacoreMessage?
  {
    if (send_requested) { return nil }
    send_requested = true
    if (defer_reply) { return nil }

    return Plasmacore.singleton._send( self )
  }

  func sendRSVP( callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    if let reply = send()
    {
      callback( reply );
    }
    else
    {
      Plasmacore.singleton.setReplyCallback( self, callback:callback )
    }
  }

  func readByte()->Int
  {
    if (position >= data.count) { return 0 }
    let result = Int( data[position] )
    position += 1
    return result
  }

  func readLogical()->Bool
  {
    return (readByte() != 0)
  }

  @discardableResult
  func readInt32()->Int
  {
    var result = readByte() << 24
    result |= readByte()    << 16
    result |= readByte()    <<  8
    return result | readByte()
  }

  @discardableResult
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
      if ((next & 0b1000_0000) == 0) { return result }
    }

    return result
  }

  func readMatrix()->matrix_float4x4
  {
    let c1 = readXYZW()
    let c2 = readXYZW()
    let c3 = readXYZW()
    let c4 = readXYZW()
    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }

  func readReal32()->Float
  {
    return Float( bitPattern:UInt32(readInt32()) )
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

  func readXYZW()->vector_float4
  {
    let x = readReal32()
    let y = readReal32()
    let z = readReal32()
    let w = readReal32()
    return vector_float4( x, y, z, w )
  }

  func skip( _ byte_count:Int )
  {
    position += byte_count
  }

  func writeByte( _ value:Int )
  {
    data.append( UInt8(value&255) )
  }

  func writeLogical( _ value:Bool )
  {
    if (value) { writeByte(1) }
    else       { writeByte(0) }
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
      writeByte( value )
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

  func writeReal32( _ value:Float )
  {
    writeInt32( Int(value.bitPattern) )
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

