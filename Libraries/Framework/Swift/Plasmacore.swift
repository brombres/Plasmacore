#if os(OSX)
import Cocoa
#else
import Foundation
#endif

import AVFoundation

class Plasmacore
{
  static let _singleton = Plasmacore()

  static var singleton:Plasmacore
  {
    get
    {
      let result = _singleton
      if (result.is_launched) { return result }
      result.configure()
      return result
    }
  }

/*
  class func start()
  {
    singleton.instanceStart( report:true )
  }

  class func stop()
  {
    singleton.instanceStop( report:true )
  }

  class func save()
  {
    PlasmacoreMessage( type:"Application.on_save" ).send()
  }
  */

  var is_configured = false
  var is_launched   = false

/*
  var idleUpdateFrequency = 0.5

  var pending_message_data = [UInt8]()
  var io_buffer = [UInt8]()

  var is_sending = false
  */

  var listeners       = [String:PlasmacoreMessageListener]()
  var reply_listeners = [Int:PlasmacoreMessageListener]()

  /*
  var resources = [Int:AnyObject]()
  var next_resource_id = 1

  var update_timer : Timer?

  fileprivate init()
  {
  }
*/

  func configure()
  {
    if (is_configured) { return }
    is_configured = true

    // Create an empty-string listener to dispatch replies
    setMessageListener( type: "", listener:
      {
        (m:PlasmacoreMessage) in
          if let info = Plasmacore.singleton.reply_listeners.removeValue( forKey:m.message_id )
          {
            info.callback( m )
          }
      }
    )

    RogueInterface_set_arg_count( Int32(CommandLine.arguments.count) )
    for (index,arg) in CommandLine.arguments.enumerated()
    {
      RogueInterface_set_arg_value( Int32(index), arg )
    }

    RogueInterface_configure();
  }

  func collect_garbage()
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)
    RogueInterface_collect_garbage()
  }

  /*
  func addResource( resource:AnyObject? )->Int
  {
    let result = next_resource_id
    next_resource_id += 1
    resources[ result ] = resource
    return result
  }

  func getResourceID( _ resource:AnyObject? )->Int
  {
    guard let resource = resource else { return 0 }

    for (key,value) in resources
    {
      if (value === resource) { return key }
    }
    return 0
  }

  @discardableResult
  func removeResource( id:Int )->AnyObject?
  {
    return resources[ id ]
  }
  */

  func launch()
  {
    if (is_launched) { return }
    is_launched = true

    configure()

    RogueInterface_launch()
/*
    let m = PlasmacoreMessage( type:"Application.on_launch" )
#if os(OSX)
  m.set( name:"is_window_based", value:true )
#endif
    m.post()
*/
  }

/*

  func relaunch()->Plasmacore
  {
    PlasmacoreMessage( type:"Application.on_launch" ).set( name:"is_window_based", value:true ).post()
    return self
  }
*/

  func removeMessageListener( type:String )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)
    listeners.removeValue( forKey:type )
  }

/*
  func setIdleUpdateFrequency( _ f:Double )->Plasmacore
  {
    idleUpdateFrequency = f
    if (update_timer != nil)
    {
      instanceStop( report:false )
      instanceStart( report:false )
    }
    return self
  }
  */

  func setMessageListener( type:String, listener:@escaping ((PlasmacoreMessage)->Void) )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    listeners[ type ] = PlasmacoreMessageListener( type:type, once:false, callback:listener )
  }

  func setReplyCallback( _ message:PlasmacoreMessage, callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)
    reply_listeners[ message.message_id ] = PlasmacoreMessageListener( type:"", once:true, callback:callback )
  }

/*
  func instanceStart( report:Bool )
  {
    if ( !is_launched ) { configure().launch() }

    if (update_timer === nil)
    {
      if (report) { PlasmacoreMessage( type:"Application.on_start" ).post() }
      update_timer = Timer.scheduledTimer( timeInterval: idleUpdateFrequency, target:self, selector: #selector(Plasmacore.update), userInfo:nil, repeats: true )
    }
    update()
  }

  func instanceStop( report:Bool )
  {
    if (update_timer !== nil)
    {
      if (report) { PlasmacoreMessage( type:"Application.on_stop" ).send() }
      update_timer!.invalidate()
      update_timer = nil
    }
  }
*/

  func dispatch( _ message:PlasmacoreMessage )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    if let listener = listeners[ message.type ]
    {
      if (listener.once) { listeners.removeValue( forKey:listener.type ) }
      listener.callback( message )
    }
  }

  func _send( _ m:PlasmacoreMessage )->PlasmacoreMessage?
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    if let result_data = RogueInterface_send_message( m.data, Int32(m.data.count) )
    {
      return PlasmacoreMessage( data:[UInt8](result_data) )
    }
    else
    {
      return nil
    }
  }

/*
  @objc func update()
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    if (is_sending) { return }
    is_sending = true

    // Swap pending data with io_buffer data
    let temp = io_buffer
    io_buffer = pending_message_data
    pending_message_data = temp

    let received_data = RogueInterface_post_messages( io_buffer, Int32(io_buffer.count) )
    let count = received_data!.count
    received_data!.withUnsafeBytes
    { (bytes:UnsafeRawBufferPointer)->Void in
      //Use `bytes` inside this closure
      //...

      var read_pos = 0
      while (read_pos+4 <= count)
      {
        var size = Int( bytes[read_pos] ) << 24
        size |= Int( bytes[read_pos+1] ) << 16
        size |= Int( bytes[read_pos+2] ) << 8
        size |= Int( bytes[read_pos+3] )
        read_pos += 4;

        if (read_pos + size <= count)
        {
          var message_data = [UInt8]()
          message_data.reserveCapacity( size )
          for i in 0..<size
          {
            message_data.append( bytes[read_pos+i] )
          }

          let m = PlasmacoreMessage( data:message_data )
          dispatch( m )
          if let reply = m._reply
          {
            reply._block_transmission = false
            reply.post()
          }
        }
        else
        {
          NSLog( "*** Skipping message due to invalid size." )
        }
        read_pos += size
      }
    }

    io_buffer.removeAll()
    is_sending = false
  }
*/
}

class PlasmacoreMessageListener
{
  //  Plasmacore.singleton.setMessageListener( type: "ArbitraryCategory.name", listener:
  //    {
  //      (m:PlasmacoreMessage) in
  //        // Unpack message
  //        let integer_32     = m.readInt32()
  //        let integet_32x    = m.readInt32X()  # 1..5 bytes
  //        let logical        = m.readLogical() # true/false
  //        let real_number_64 = m.readReal64()
  //        let string         = m.readString()
  //
  //        // Optional reply
  //        let reply = m.reply()
  //        reply.writeInt32X( value:value )
  //        ...
  //        reply.send()  # 'reply' can be saved and sent later
  //    }
  //  )
  var type      : String
  let once      : Bool
  var callback  : ((PlasmacoreMessage)->Void)

  init( type:String, once:Bool, callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    self.type = type
    self.once = once
    self.callback = callback
  }
}

