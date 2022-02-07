let sizeOfUniforms = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

class RenderData
{
  let device               : MTLDevice
  let maxFrames            : Int       // AKA maxBuffersInFlight

  var frame                = 0         // 0..(maxFrames-1)

  var positionCapacity     = 384  // must be at least 3 to start
  var positionBuffer       : MTLBuffer
  public var positionCount = 0
  public var positions     : UnsafeMutablePointer<Float>

  var colorCapacity        = 256  // must be at least 4 to start
  var colorBuffer          : MTLBuffer
  var colorCount           = 0
  public var colors        : UnsafeMutablePointer<Float>

  var uniformsCapacity     = 8  // must be at least 1 to start
  var uniformsBuffer       : MTLBuffer
  var uniformsCount        = 0
  public var uniforms      : UnsafeMutablePointer<Uniforms>

  var projectionTransformStack = [matrix_float4x4]()
  var objectTransformStack     = [matrix_float4x4]()
  var viewTransformStack       = [matrix_float4x4]()
  var worldTransformStack      = [matrix_float4x4]()

  init( _ device:MTLDevice, _ maxFrames:Int  )
  {
    self.device = device
    self.maxFrames = maxFrames

    positionBuffer = device.makeBuffer(
                       length:(positionCapacity*4*maxFrames),
                       options:[MTLResourceOptions.storageModeShared]
                     )!
    colorBuffer = device.makeBuffer(
                    length:(colorCapacity*4*maxFrames),
                    options:[MTLResourceOptions.storageModeShared]
                  )!
    uniformsBuffer = device.makeBuffer(
                       length:(uniformsCapacity*sizeOfUniforms*maxFrames),
                       options:[MTLResourceOptions.storageModeShared]
                     )!

    positions = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    colors = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    uniforms = RenderData.makeUniformsBufferPointer( uniformsBuffer, uniformsCapacity, frame )
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

  func addUniforms()
  {
    if (uniformsCount + 1 > uniformsCapacity) { reserveUniformsCapacity(uniformsCapacity*2) }
    uniformsCount += 1
  }

  func advanceFrame()
  {
    frame = (frame + 1) % maxFrames
    positionCount = 0
    colorCount = 0
    uniformsCount = 0
    updateBufferPointers()
    clearTransforms()
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

  func bindUniformsBuffer( _ renderEncoder:MTLRenderCommandEncoder, _ index:Int )
  {
    if (uniformsCount == 0) { addUniforms(); }
    let offset = (uniformsCapacity * frame + (uniformsCount-1)) * sizeOfUniforms
    renderEncoder.setVertexBuffer( uniformsBuffer, offset:offset, index:index )
    renderEncoder.setFragmentBuffer( uniformsBuffer, offset:offset, index:index )
  }

  func clearTransforms()
  {
    projectionTransformStack.removeAll()
    objectTransformStack.removeAll()
    viewTransformStack.removeAll()
    worldTransformStack.removeAll()
  }

  func pushObjectTransform( _ transform:matrix_float4x4 )
  {
    let objectTransform : matrix_float4x4
    if let existingObjectTransform = objectTransformStack.last
    {
      objectTransform = simd_mul( existingObjectTransform, transform )
      objectTransformStack.append( objectTransform )
    }
    else
    {
      objectTransform = transform
      objectTransformStack.append( transform )
    }

    if let viewTransform = viewTransformStack.last
    {
      worldTransformStack.append( simd_mul(viewTransform,objectTransform) )
    }
    else
    {
      worldTransformStack.append( objectTransform )
    }
  }

  func pushProjectionTransform( _ transform:matrix_float4x4 )
  {
    projectionTransformStack.append( transform )
  }

  func pushViewTransform( _ transform:matrix_float4x4 )
  {
    let viewTransform : matrix_float4x4
    if let existingViewTransform = viewTransformStack.last
    {
      viewTransform = simd_mul( existingViewTransform, transform )
      viewTransformStack.append( viewTransform )
    }
    else
    {
      viewTransform = transform
      viewTransformStack.append( transform )
    }

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
      colorCapacity = requiredCapacity
      colorBuffer = device.makeBuffer( length:(colorCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      colors    = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    }
  }

  func reservePositionCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = positionCount + additionalCapacity
    if (requiredCapacity > positionCapacity)
    {
      positionCapacity = requiredCapacity
      positionBuffer = device.makeBuffer( length:(positionCapacity*4*maxFrames), options:[MTLResourceOptions.storageModeShared] )!
      positions = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    }
  }

  func reserveUniformsCapacity( _ additionalCapacity:Int )
  {
    let requiredCapacity = uniformsCount + additionalCapacity
    if (requiredCapacity > uniformsCapacity)
    {
      uniformsCapacity = requiredCapacity
      uniformsBuffer = device.makeBuffer(
                         length:(uniformsCapacity*sizeOfUniforms*maxFrames),
                         options:[MTLResourceOptions.storageModeShared]
                       )!
      uniforms = RenderData.makeUniformsBufferPointer( uniformsBuffer, uniformsCapacity, frame )
    }
  }

  func updateBufferPointers()
  {
    positions = RenderData.makeFloatBufferPointer( positionBuffer, positionCapacity, frame )
    colors    = RenderData.makeFloatBufferPointer( colorBuffer, colorCapacity, frame )
    uniforms  = RenderData.makeUniformsBufferPointer( uniformsBuffer, uniformsCapacity, frame )
  }

  //----------------------------------------------------------------------------
  // Class Functions
  //----------------------------------------------------------------------------
  class func makeFloatBufferPointer( _ buffer:MTLBuffer, _ capacity:Int, _ frame:Int )->UnsafeMutablePointer<Float>
  {
    let offset = capacity * 4 * frame
    return UnsafeMutableRawPointer( buffer.contents() + offset ).bindMemory( to:Float.self, capacity:capacity )
  }

  class func makeUniformsBufferPointer( _ buffer:MTLBuffer, _ capacity:Int, _ frame:Int )->UnsafeMutablePointer<Uniforms>
  {
    let offset = capacity * sizeOfUniforms * frame
    return UnsafeMutableRawPointer(buffer.contents() + offset).bindMemory(to:Uniforms.self, capacity:capacity)
  }
}

