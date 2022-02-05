class RenderBuffer
{
  let device               : MTLDevice
  let maxFrames            : Int       // AKA maxBuffersInFlight

  var frame                = 0         // 0..(maxFrames-1)

  var positionCapacity     = 100
  var positionBuffer       : MTLBuffer
  public var positionCount = 0
  public var positions     : UnsafeMutablePointer<Float>

  var colorCapacity        = 100
  var colorBuffer          : MTLBuffer
  var colorCount           = 0
  public var colors        : UnsafeMutablePointer<Float>

  init( _ device:MTLDevice, _ maxFrames:Int  )
  {
    self.device = device
    self.maxFrames = maxFrames

    positionBuffer = device.makeBuffer( length:(positionCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
    colorBuffer = device.makeBuffer( length:(colorCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
    positions = RenderBuffer.makeBufferPointer( positionBuffer, positionCapacity, frame )
    colors = RenderBuffer.makeBufferPointer( colorBuffer, colorCapacity, frame )
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
    positionCount = 0
    colorCount = 0
    updateBufferPointers()
  }

  func bindColorBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ firstIndex:Int, _ index:Int )
  {
    let offset = (colorCapacity * frame + firstIndex) * 4
    renderEncoder.setVertexBuffer( colorBuffer, offset:offset, index:index )
  }

  func bindPositionBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ firstIndex:Int, _ index:Int )
  {
    let offset = (positionCapacity * frame + firstIndex) * 4
    renderEncoder.setVertexBuffer( positionBuffer, offset:offset, index:index )
  }

  func reserveColorCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = colorCount + additionalCapacity
    if (requiredCapacity > colorCapacity)
    {
      colorCapacity = requiredCapacity
      colorBuffer = device.makeBuffer( length:(colorCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      colors    = RenderBuffer.makeBufferPointer( colorBuffer, colorCapacity, frame )
    }
  }

  func reservePositionCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = positionCount + additionalCapacity
    if (requiredCapacity > positionCapacity)
    {
      positionCapacity = requiredCapacity
      positionBuffer = device.makeBuffer( length:(positionCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      positions = RenderBuffer.makeBufferPointer( positionBuffer, positionCapacity, frame )
    }
  }

  func updateBufferPointers()
  {
    positions = RenderBuffer.makeBufferPointer( positionBuffer, positionCapacity, frame )
    colors    = RenderBuffer.makeBufferPointer( colorBuffer, colorCapacity, frame )
  }

  //----------------------------------------------------------------------------
  // Class Functions
  //----------------------------------------------------------------------------
  class func makeBufferPointer( _ buffer:MTLBuffer, _ capacity:Int, _ frame:Int )->UnsafeMutablePointer<Float>
  {
    let offset = capacity * 4 * frame
    return UnsafeMutableRawPointer( buffer.contents() + offset ).bindMemory( to:Float.self, capacity:capacity )
  }
}

