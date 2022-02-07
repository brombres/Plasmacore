//==============================================================================
// RenderMode
//==============================================================================
class RenderMode
{
  let renderer : Renderer
  var vertexDescriptor   : MTLVertexDescriptor?
  var pipeline           : MTLRenderPipelineState?
  var firstPositionIndex = 0


  init( _ renderer:Renderer )
  {
    self.renderer = renderer
  }

  func activate()
  {
    firstPositionIndex = renderer.renderData.positionCount
  }

  func reserveCapacity( _ n:Int )
  {
    preconditionFailure( "Override required." )
  }

  func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    renderEncoder.setRenderPipelineState( pipeline! )

    let renderData = renderer.renderData

    if let projectionTransform = renderData.projectionTransformStack.last
    {
      renderData.uniforms[0].projectionTransform = projectionTransform
    }
    else
    {
      renderData.uniforms[0].projectionTransform = Matrix.identity()
    }

    if let worldTransform = renderData.worldTransformStack.last
    {
      renderData.uniforms[0].worldTransform = worldTransform
    }
    else
    {
      renderData.uniforms[0].worldTransform = Matrix.identity()
    }
  }
}

//==============================================================================
// RenderModeColoredShapes
//==============================================================================
class RenderModeColoredShapes : RenderMode
{
  var firstColorIndex = 0

  init( _ renderer:Renderer, _ label:String )
  {
    super.init( renderer )

    //--------------------------------------------------------------------------
    // Vertex Descriptor
    //--------------------------------------------------------------------------
    let vertexDescriptor = MTLVertexDescriptor()
    self.vertexDescriptor = vertexDescriptor

    vertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].offset = 0
    vertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].bufferIndex = ColoredBufferIndex.meshPositions.rawValue

    vertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].offset = 0
    vertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].bufferIndex = ColoredBufferIndex.meshGenerics.rawValue

    vertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stride = 12
    vertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stepRate = 1
    vertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    vertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stride = 16
    vertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stepRate = 1
    vertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    //--------------------------------------------------------------------------
    // Pipeline
    //--------------------------------------------------------------------------
    do
    {
      let vertexFunction = renderer.shaderLibrary?.makeFunction(name: "coloredVertexShader")
      let fragmentFunction = renderer.shaderLibrary?.makeFunction(name: "coloredFragmentShader")
      let metalKitView = renderer.metalKitView

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.label = label
      pipelineDescriptor.sampleCount = metalKitView.sampleCount
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.vertexDescriptor = vertexDescriptor

      pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
      pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipeline = try renderer.device.makeRenderPipelineState( descriptor:pipelineDescriptor )
    }
    catch
    {
      print("Unable to compile \(label) pipeline state: \(error)")
    }
  }

  override func activate()
  {
    super.activate()
    firstColorIndex = renderer.renderData.colorCount
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.render( renderEncoder )

    let renderData = renderer.renderData
    renderData.bindPositionBuffer( renderEncoder, firstPositionIndex, ColoredBufferIndex.meshPositions.rawValue )
    renderData.bindColorBuffer( renderEncoder, firstColorIndex, ColoredBufferIndex.meshGenerics.rawValue )
    renderData.bindUniformsBuffer( renderEncoder, ColoredBufferIndex.uniforms.rawValue )
  }
}

//==============================================================================
// RenderModeDrawLines
//==============================================================================
class RenderModeDrawLines : RenderModeColoredShapes
{
  let verticesPerLine = 2
  let positionValuesPerVertex = 3
  let colorValuesPerVertex    = 4

  init( _ renderer:Renderer )
  {
    super.init( renderer, "DrawLines" )
  }

  override func reserveCapacity( _ n:Int )
  {
    renderer.renderData.reservePositionCapacity( n * positionValuesPerVertex * verticesPerLine )
    renderer.renderData.reserveColorCapacity( n * colorValuesPerVertex * verticesPerLine )
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.render( renderEncoder )

    let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:        MTLPrimitiveType.line,
      vertexStart: 0,
      vertexCount: count
    )
  }
}

//==============================================================================
// RenderModeFillSolidTriangles
//==============================================================================
class RenderModeFillSolidTriangles : RenderModeColoredShapes
{
  let verticesPerTriangle = 3
  let positionValuesPerVertex = 3
  let colorValuesPerVertex    = 4

  init( _ renderer:Renderer )
  {
    super.init( renderer, "FillSolidTriangles" )
  }

  override func reserveCapacity( _ n:Int )
  {
    renderer.renderData.reservePositionCapacity( n * positionValuesPerVertex * verticesPerTriangle )
    renderer.renderData.reserveColorCapacity( n * colorValuesPerVertex * verticesPerTriangle )
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.render( renderEncoder )

    let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:          MTLPrimitiveType.triangle,
      vertexStart:   0,
      vertexCount:   count
    )
  }
}


// Texture stuff
  //  texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
  //  texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].offset = 0
  //  texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].bufferIndex = TexturedBufferIndex.meshGenerics.rawValue

  //  texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stride = 8
  //  texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stepRate = 1
  //  texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

  //class func buildTexturedPipeline( device:MTLDevice, metalKitView:MTKView,
  //    shaderLibrary:MTLLibrary?, texturedVertexDescriptor:MTLVertexDescriptor )
  //    throws -> MTLRenderPipelineState
  //{
  //  let vertexFunction = shaderLibrary?.makeFunction(name: "texturedVertexShader")
  //  let fragmentFunction = shaderLibrary?.makeFunction(name: "texturedFragmentShader")

  //  let pipelineDescriptor = MTLRenderPipelineDescriptor()
  //  pipelineDescriptor.label = "RenderPipeline"
  //  pipelineDescriptor.sampleCount = metalKitView.sampleCount
  //  pipelineDescriptor.vertexFunction = vertexFunction
  //  pipelineDescriptor.fragmentFunction = fragmentFunction
  //  pipelineDescriptor.vertexDescriptor = texturedVertexDescriptor

  //  pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
  //  pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
  //  pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

  //  return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  //}

  //func prepareDemoAssets()
  //{
  //  do
  //  {
  //    mesh = try Renderer.buildMesh(device: device, texturedVertexDescriptor: texturedVertexDescriptor)
  //  }
  //  catch
  //  {
  //    print("Unable to build MetalKit Mesh. Error info: \(error)")
  //    return
  //  }

  //  do
  //  {
  //    colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
  //  }
  //  catch
  //  {
  //    print("Unable to load texture. Error info: \(error)")
  //    return
  //  }
  //}

  //class func buildMesh( device:MTLDevice, texturedVertexDescriptor:MTLVertexDescriptor) throws -> MTKMesh
  //{
  //  /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
  //  let metalAllocator = MTKMeshBufferAllocator(device: device)
  //  let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
  //      segments: SIMD3<UInt32>(2, 2, 2),
  //      geometryType: MDLGeometryType.triangles,
  //      inwardNormals:false,
  //      allocator: metalAllocator)

  //  let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(texturedVertexDescriptor)

  //  guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else
  //  {
  //    throw RendererError.badVertexDescriptor
  //  }
  //  attributes[TexturedVertexAttribute.position.rawValue].name = MDLVertexAttributePosition
  //  attributes[TexturedVertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

  //  mdlMesh.vertexDescriptor = mdlVertexDescriptor

  //  return try MTKMesh(mesh:mdlMesh, device:device)
  //}

  //class func loadTexture(device: MTLDevice,
  //    textureName: String) throws -> MTLTexture
  //{
  //  /// Load texture data with optimal parameters for sampling
  //  let textureLoader = MTKTextureLoader(device: device)

  //  let textureLoaderOptions =
  //  [
  //    MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
  //    MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
  //  ]

  //  return try textureLoader.newTexture(
  //    name        : textureName,
  //    scaleFactor : 1.0,
  //    bundle      : nil,
  //    options     : textureLoaderOptions
  //  )
  //}

        //----------------------------------------------------------------------
        // Cube
        //----------------------------------------------------------------------
        //renderEncoder.setRenderPipelineState(texturedPipeline)
        //renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: TexturedBufferIndex.uniforms.rawValue)
        //renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: TexturedBufferIndex.uniforms.rawValue)

        //for (index, element) in mesh!.vertexDescriptor.layouts.enumerated()
        //{
        //  guard let layout = element as? MDLVertexBufferLayout else { return }
        //  if layout.stride != 0
        //  {
        //    let buffer = mesh!.vertexBuffers[index]
        //    renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
        //  }
        //}

        //renderEncoder.setFragmentTexture(colorMap!, index:TextureIndex.color.rawValue)

        //for submesh in mesh!.submeshes
        //{
        //  renderEncoder.drawIndexedPrimitives(
        //    type: submesh.primitiveType,
        //    indexCount: submesh.indexCount,
        //    indexType: submesh.indexType,
        //    indexBuffer: submesh.indexBuffer.buffer,
        //    indexBufferOffset: submesh.indexBuffer.offset
        //  )
        //}

