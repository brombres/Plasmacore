class RenderBuffer
{
  let device               : MTLDevice
  let maxFrames            : Int       // AKA maxBuffersInFlight

  var frame                = 0         // 0..(maxFrames-1)

  var positionCapacity     = 384  // must be 3 or higher
  var positionBuffer       : MTLBuffer
  public var positionCount = 0
  public var positions     : UnsafeMutablePointer<Float>

  var colorCapacity        = 256  // must be 4 or higher
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

  func addColor( _ r:Float, _ g:Float, _ b:Float, _ a:Float )
  {
    if (colorCount + 4 > colorCapacity) { reserveColorCapacity(colorCapacity*2) }
    colors[colorCount]   = r
    colors[colorCount+1] = g
    colors[colorCount+2] = b
    colors[colorCount+3] = a
    colorCount += 4
  }

  func addColor( _ argb:Int )
  {
    let a = Float((argb >> 24) & 255) / 255.0
    let r = Float((argb >> 16) & 255) / 255.0
    let g = Float((argb >> 8) & 255) / 255.0
    let b = Float(argb & 255) / 255.0
    addColor( r, g, b, a )
  }

  func addPosition( _ x:Float, _ y:Float, _ z:Float )
  {
    if (positionCount + 3 > positionCapacity) { reservePositionCapacity(positionCapacity*2) }
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

