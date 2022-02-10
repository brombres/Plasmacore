let sizeOfFloat    = 4
let sizeOfConstants = (MemoryLayout<Constants>.size + 0xFF) & -0x100

class RenderData
{
  let device               : MTLDevice
  let maxFrames            : Int       // AKA maxBuffersInFlight

  var frame                = 0         // 0..(maxFrames-1)

  var positionCapacity     = 384
  var positionBuffer       : MTLBuffer
  public var positionCount = 0
  public var positions     : UnsafeMutablePointer<Float>

  var colorCapacity        = 256
  var colorBuffer          : MTLBuffer
  var colorCount           = 0
  public var colors        : UnsafeMutablePointer<Float>

  var constantsCapacity     = 8
  var constantsBuffer       : MTLBuffer
  var constantsCount        = 0
  public var constants      : UnsafeMutablePointer<Constants>

  var uvCapacity           = 128
  var uvBuffer             : MTLBuffer
  var uvCount              = 0
  public var uvs           : UnsafeMutablePointer<Float>


  var projectionTransformStack = [matrix_float4x4]()
  var objectTransformStack     = [matrix_float4x4]()
  var viewTransformStack       = [matrix_float4x4]()
  var worldTransformStack      = [matrix_float4x4]()

  init( _ device:MTLDevice, _ maxFrames:Int  )
  {
    self.device = device
    self.maxFrames = maxFrames

    positionBuffer = device.makeBuffer(
      length:(positionCapacity*sizeOfFloat*maxFrames),
      options:[MTLResourceOptions.storageModeShared]
    )!
    colorBuffer = device.makeBuffer(
      length:(colorCapacity*sizeOfFloat*maxFrames),
      options:[MTLResourceOptions.storageModeShared]
    )!
    constantsBuffer = device.makeBuffer(
      length:(constantsCapacity*sizeOfConstants*maxFrames),
      options:[MTLResourceOptions.storageModeShared]
    )!
    uvBuffer = device.makeBuffer(
      length:(uvCapacity*sizeOfFloat*maxFrames),
      options:[MTLResourceOptions.storageModeShared]
    )!

    positions = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    colors = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    constants = RenderData.makeConstantsBufferPointer( constantsBuffer, constantsCapacity, frame )
    uvs = RenderData.makeFloatBufferPointer( uvBuffer, uvCapacity, frame )
  }

  func addColor( _ r:Float, _ g:Float, _ b:Float, _ a:Float )
  {
    if (colorCount + 4 > colorCapacity) { reserveColorCapacity(colorCapacity) }
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
    if (positionCount + 3 > positionCapacity) { reservePositionCapacity(positionCapacity) }
    positions[positionCount]   = x
    positions[positionCount+1] = y
    positions[positionCount+2] = z
    positionCount += 3
  }

  func addConstants()
  {
    if (constantsCount + 1 > constantsCapacity) { reserveConstantsCapacity(constantsCapacity) }
    constantsCount += 1
  }

  func addUV( _ u:Float, _ v:Float )
  {
    if (uvCount + 2 > uvCapacity) { reserveUVCapacity(uvCapacity) }
    uvs[uvCount]   = u
    uvs[uvCount+1] = v
    uvCount += 2
  }

  func advanceFrame()
  {
    frame = (frame + 1) % maxFrames
    positionCount = 0
    colorCount = 0
    constantsCount = 0
    uvCount = 0
    updateBufferPointers()
    clearTransforms()
  }

  func bindColorBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ firstIndex:Int, _ index:Int )
  {
    let offset = (colorCapacity * frame + firstIndex) * sizeOfFloat
    renderEncoder.setVertexBuffer( colorBuffer, offset:offset, index:index )
  }

  func bindPositionBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ firstIndex:Int, _ index:Int )
  {
    let offset = (positionCapacity * frame + firstIndex) * sizeOfFloat
    renderEncoder.setVertexBuffer( positionBuffer, offset:offset, index:index )
  }

  func bindConstantsBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ index:Int )
  {
    if (constantsCount == 0) { addConstants(); }
    let offset = (constantsCapacity * frame + (constantsCount-1)) * sizeOfConstants
    renderEncoder.setVertexBuffer( constantsBuffer, offset:offset, index:index )
    renderEncoder.setFragmentBuffer( constantsBuffer, offset:offset, index:index )
  }

  func bindUVBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ firstIndex:Int, _ index:Int )
  {
    let offset = (uvCapacity * frame + firstIndex) * sizeOfFloat
    renderEncoder.setVertexBuffer( uvBuffer, offset:offset, index:index )
  }

  func clearTransforms()
  {
    projectionTransformStack.removeAll()
    objectTransformStack.removeAll()
    viewTransformStack.removeAll()
    worldTransformStack.removeAll()
  }

  func pushObjectTransform( _ transform:matrix_float4x4, _ replace:Bool )
  {
    var objectTransform = transform
    if (!replace)
    {
      if let existingObjectTransform = objectTransformStack.last
      {
        objectTransform = simd_mul( existingObjectTransform, transform )
      }
    }
    objectTransformStack.append( objectTransform )

    if let viewTransform = viewTransformStack.last
    {
      worldTransformStack.append( simd_mul(viewTransform,objectTransform) )
    }
    else
    {
      worldTransformStack.append( objectTransform )
    }
  }

  func pushProjectionTransform( _ transform:matrix_float4x4, _ replace:Bool )
  {
    var projectionTransform = transform
    if (!replace)
    {
      if let existingProjectionTransform = projectionTransformStack.last
      {
        projectionTransform = simd_mul( existingProjectionTransform, transform )
      }
    }
    projectionTransformStack.append( projectionTransform )
  }

  func pushViewTransform( _ transform:matrix_float4x4, _ replace:Bool )
  {
    var viewTransform = transform
    if (!replace)
    {
      if let existingViewTransform = viewTransformStack.last
      {
        viewTransform = simd_mul( existingViewTransform, transform )
      }
    }
    viewTransformStack.append( viewTransform )


    if let objectTransform = objectTransformStack.last
    {
      worldTransformStack.append( simd_mul(viewTransform,objectTransform) )
    }
    else
    {
      worldTransformStack.append( viewTransform )
    }
  }

  func popObjectTransform()
  {
    if (objectTransformStack.count > 0)
    {
      objectTransformStack.removeLast()
      worldTransformStack.removeLast()
    }
  }

  func popProjectionTransform()
  {
    if (projectionTransformStack.count > 0)
    {
      projectionTransformStack.removeLast()
    }
  }

  func popViewTransform()
  {
    if (viewTransformStack.count > 0)
    {
      viewTransformStack.removeLast()
      worldTransformStack.removeLast()
    }
  }

  func reserveColorCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = colorCount + additionalCapacity
    if (requiredCapacity > colorCapacity)
    {
      let newBuffer = device.makeBuffer( length:(requiredCapacity*sizeOfFloat*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      newBuffer.contents().copyMemory( from:colors, byteCount:colorCapacity*sizeOfFloat )
      colorBuffer   = newBuffer
      colorCapacity = requiredCapacity
      colors        = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    }
  }

  func reservePositionCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = positionCount + additionalCapacity
    if (requiredCapacity > positionCapacity)
    {
      let newBuffer = device.makeBuffer( length:(requiredCapacity*sizeOfFloat*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      newBuffer.contents().copyMemory( from:positions, byteCount:positionCapacity*sizeOfFloat )
      positionBuffer   = newBuffer
      positionCapacity = requiredCapacity
      positions        = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    }
  }

  func reserveConstantsCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = constantsCount + additionalCapacity
    if (requiredCapacity > constantsCapacity)
    {
      let byteCountPerFrame = constantsCapacity*sizeOfConstants
      let newBuffer = device.makeBuffer( length:(byteCountPerFrame*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      newBuffer.contents().copyMemory( from:constants, byteCount:byteCountPerFrame )
      constantsBuffer  = newBuffer
      constantsCapacity = requiredCapacity
      constants        = RenderData.makeConstantsBufferPointer( constantsBuffer, constantsCapacity, frame )
    }
  }

  func reserveUVCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = uvCount + additionalCapacity
    if (requiredCapacity > uvCapacity)
    {
      let newBuffer = device.makeBuffer( length:(requiredCapacity*sizeOfFloat*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      newBuffer.contents().copyMemory( from:uvs, byteCount:uvCapacity*sizeOfFloat )
      uvBuffer   = newBuffer
      uvCapacity = requiredCapacity
      uvs        = RenderData.makeFloatBufferPointer( uvBuffer, uvCapacity, frame )
    }
  }

  func updateBufferPointers()
  {
    positions = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    colors    = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    constants  = RenderData.makeConstantsBufferPointer( constantsBuffer, constantsCapacity, frame )
    uvs       = RenderData.makeFloatBufferPointer( uvBuffer, uvCapacity, frame )
  }

  //----------------------------------------------------------------------------
  // Class Functions
  //----------------------------------------------------------------------------
  class func makeFloatBufferPointer( _ buffer:MTLBuffer, _ capacity:Int, _ frame:Int )->UnsafeMutablePointer<Float>
  {
    let offset = capacity * sizeOfFloat * frame
    return UnsafeMutableRawPointer( buffer.contents() + offset ).bindMemory( to:Float.self, capacity:capacity )
  }

  class func makeConstantsBufferPointer( _ buffer:MTLBuffer, _ capacity:Int, _ frame:Int )->UnsafeMutablePointer<Constants>
  {
    let offset = capacity * sizeOfConstants * frame
    return UnsafeMutableRawPointer(buffer.contents() + offset).bindMemory(to:Constants.self, capacity:capacity)
  }
}

