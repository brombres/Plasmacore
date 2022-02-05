class RenderBuffer
{
  let device               : MTLDevice
  let maxFrames            : Int       // AKA maxBuffersInFlight

  var frame                = 0         // 0..(maxFrames-1)

  var positionCapacity     = 6144      // must be a power of 2 for bitwise ops
  var positionBuffer       : MTLBuffer
  public var positionCount = 0
  public var positions     : UnsafeMutablePointer<Float>

  var colorCapacity        = 8192
  var colorBuffer          : MTLBuffer
  var colorCount           = 0
  public var colors        : UnsafeMutablePointer<Float>

  init( _ device:MTLDevice, _ maxFrames:Int  )
  {
    self.device = device
    self.maxFrames = maxFrames

    positionBuffer = device.makeBuffer( length:(positionCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
    positions = UnsafeMutableRawPointer( positionBuffer.contents() ).bindMemory( to:Float.self, capacity:positionCapacity )

    colorBuffer = device.makeBuffer( length:(colorCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
    colors = UnsafeMutableRawPointer( colorBuffer.contents() ).bindMemory( to:Float.self, capacity:colorCapacity )
  }

  func addColor( _ b:Float, _ r:Float, _ g:Float, _ a:Float )
  {
    colors[colorCount]   = b
    colors[colorCount+1] = r
    colors[colorCount+2] = g
    colors[colorCount+3] = a
    colorCount += 4
  }

  func addPosition( _ x:Float, _ y:Float, _ z:Float )
  {
    positions[positionCount]   = x
    positions[positionCount+1] = y
    positions[positionCount+2] = z
    positionCount += 3
  }

  func advanceFrame()
  {
    frame = (frame + 1) % maxFrames

    var offset = positionCapacity * 4 * frame
    positions = UnsafeMutableRawPointer( positionBuffer.contents() + offset ).bindMemory( to:Float.self, capacity:positionCapacity )
    positionCount = 0

    offset = colorCapacity * 4 * frame
    colors = UnsafeMutableRawPointer( colorBuffer.contents() + offset ).bindMemory( to:Float.self, capacity:colorCapacity )
    colorCount = 0
  }

  func bindColorBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ index:Int )
  {
    let offset = colorCapacity * 4 * frame
    renderEncoder.setVertexBuffer( colorBuffer, offset:offset, index:index )
  }

  func bindPositionBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ index:Int )
  {
    let offset = positionCapacity * 4 * frame
    renderEncoder.setVertexBuffer( positionBuffer, offset:offset, index:index )
  }

  func ensureColorCapacity( _ capacity:Int )
  {
    if (capacity > colorCapacity)
    {
      colorCapacity = capacity
      colorBuffer = device.makeBuffer( length:(colorCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      let offset = colorCapacity * 4 * frame
      colors = UnsafeMutableRawPointer( colorBuffer.contents() + offset ).bindMemory( to:Float.self, capacity:colorCapacity )
    }
  }

  func ensurePositionCapacity( _ capacity:Int )
  {
    if (capacity > positionCapacity)
    {
      positionCapacity = capacity
      positionBuffer = device.makeBuffer( length:(positionCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      let offset = positionCapacity * 4 * frame
      positions = UnsafeMutableRawPointer( positionBuffer.contents() + offset ).bindMemory( to:Float.self, capacity:positionCapacity )
    }
  }
}

