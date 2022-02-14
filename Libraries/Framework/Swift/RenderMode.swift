//==============================================================================
// RenderMode
//==============================================================================
class RenderMode
{
  let positionValuesPerVertex = 3

  let renderer           : Renderer
  let renderModeID       : Int
  let shape              : Int   // 1:points, 2:lines, 3:triangles

  var vertexDescriptor   : MTLVertexDescriptor?
  var pipeline           : MTLRenderPipelineState?
  var firstPositionIndex = 0
  var firstColorIndex    = 0
  var firstUVIndex       = 0
  var needsRender        = false
  var renderEncoder      : MTLRenderCommandEncoder?
  var texture            : MTLTexture?
  var sampler            : MTLSamplerState?

  init( _ renderer:Renderer, _ renderModeID:Int, _ shape:Int, _ sourceBlend:MTLBlendFactor?, _ destinationBlend:MTLBlendFactor?,
        _ vertexShaderName:String, _ fragmentShaderName:String )
  {
    self.renderModeID = renderModeID
    self.renderer = renderer
    self.shape = shape

    //--------------------------------------------------------------------------
    // Vertex Descriptor
    //--------------------------------------------------------------------------
    let vertexDescriptor = MTLVertexDescriptor()
    self.vertexDescriptor = vertexDescriptor

    vertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
    vertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = VertexBufferIndex.positions.rawValue

    vertexDescriptor.attributes[VertexAttribute.color.rawValue].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[VertexAttribute.color.rawValue].offset = 0
    vertexDescriptor.attributes[VertexAttribute.color.rawValue].bufferIndex = VertexBufferIndex.colors.rawValue

    vertexDescriptor.attributes[VertexAttribute.UV.rawValue].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[VertexAttribute.UV.rawValue].offset = 0
    vertexDescriptor.attributes[VertexAttribute.UV.rawValue].bufferIndex = VertexBufferIndex.uvs.rawValue

    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stride = 12
    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stride = 16
    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    vertexDescriptor.layouts[VertexBufferIndex.uvs.rawValue].stride = 8
    vertexDescriptor.layouts[VertexBufferIndex.uvs.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.uvs.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    //--------------------------------------------------------------------------
    // Pipeline
    //--------------------------------------------------------------------------
    do
    {
      let vertexFunction = renderer.shaderLibrary?.makeFunction(name:vertexShaderName)
      let fragmentFunction = renderer.shaderLibrary?.makeFunction(name:fragmentShaderName)
      let metalKitView = renderer.metalKitView

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.sampleCount = metalKitView.sampleCount
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.vertexDescriptor = vertexDescriptor

      pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
      if (sourceBlend != nil && destinationBlend != nil)
      {
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = sourceBlend!
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = destinationBlend!
      }
      pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipeline = try renderer.device.makeRenderPipelineState( descriptor:pipelineDescriptor )
    }
    catch
    {
      print("Unable to compile pipeline state: \(error)")
    }

    //--------------------------------------------------------------------------
    // Sampler
    //--------------------------------------------------------------------------
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = MTLSamplerMinMagFilter.linear // 'nearest' for pixellated
    samplerDescriptor.magFilter = MTLSamplerMinMagFilter.linear // 'nearest' for pixellated
    sampler = renderer.device.makeSamplerState( descriptor:samplerDescriptor )
  }

  @discardableResult
  func activate( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if (self === renderer.renderMode)
    {
      // Already active.
      if ( !needsRender ) { reactivate() }
      return false
    }

    self.renderEncoder = renderEncoder
    renderer.renderMode?.render()  // flush the queue of the previous render mode
    renderer.renderMode = self
    reactivate()
    texture = nil
    return true
  }

  func reactivate()
  {
    firstPositionIndex = renderer.renderData.positionCount
    firstColorIndex    = renderer.renderData.colorCount
    firstUVIndex       = renderer.renderData.uvCount

    needsRender = true
  }

  @discardableResult
  func render()->Bool
  {
    if ( !needsRender ) { return false }
    if (firstPositionIndex == renderer.renderData.positionCount) { return false }
    guard let renderEncoder = renderEncoder else { return false }

    needsRender = false
    renderEncoder.setRenderPipelineState( pipeline! )
    if let sampler = sampler
    {
      renderEncoder.setFragmentSamplerState( sampler, index:0 )
    }

    let renderData = renderer.renderData
    renderData.setShaderConstants()
    renderData.bindPositionBuffer( renderEncoder, firstPositionIndex, VertexBufferIndex.positions.rawValue )
    renderData.bindColorBuffer( renderEncoder, firstColorIndex, VertexBufferIndex.colors.rawValue )
    renderData.bindUVBuffer( renderEncoder, firstUVIndex, VertexBufferIndex.uvs.rawValue )
    renderData.bindConstantsBuffer( renderEncoder, VertexBufferIndex.constants.rawValue )

    switch (shape)
    {
      case 2:  // lines
        let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
        renderEncoder.drawPrimitives(
          type:        MTLPrimitiveType.line,
          vertexStart: 0,
          vertexCount: count
        )

      case 3:  // triangles
        if let texture = self.texture
        {
          renderEncoder.setFragmentTexture( texture, index:TextureStage.color.rawValue )
        }
        let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
        renderEncoder.drawPrimitives(
          type:          MTLPrimitiveType.triangle,
          vertexStart:   0,
          vertexCount:   count
        )

      default:
        return false
    }

    return true
  }

  func setTexture( _ newTexture:MTLTexture? )
  {
    if (newTexture === texture) { return }
    render()  // flush
    texture = newTexture
  }
}

