//==============================================================================
// RenderMode
//==============================================================================
class RenderMode
{
  let renderer           : Renderer
  var vertexDescriptor   : MTLVertexDescriptor?
  var pipeline           : MTLRenderPipelineState?
  var firstPositionIndex = 0
  var needsRender        = false


  init( _ renderer:Renderer )
  {
    self.renderer = renderer
  }

  func activate( _ renderEncoder:MTLRenderCommandEncoder )
  {
    renderer.renderMode?.render( renderEncoder )
    renderer.renderMode = self
    firstPositionIndex = renderer.renderData.positionCount
    needsRender = true
  }

  func reserveCapacity( _ n:Int )
  {
    preconditionFailure( "Override required." )
  }

  @discardableResult
  func render( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if ( !needsRender ) { return false }
    if (firstPositionIndex == renderer.renderData.positionCount) { return false }

    needsRender = false
    renderEncoder.setRenderPipelineState( pipeline! )

    let renderData = renderer.renderData

    if let projectionTransform = renderData.projectionTransformStack.last
    {
      renderData.constants[0].projectionTransform = projectionTransform
    }
    else
    {
      renderData.constants[0].projectionTransform = Matrix.identity()
    }

    if let worldTransform = renderData.worldTransformStack.last
    {
      renderData.constants[0].worldTransform = worldTransform
    }
    else
    {
      renderData.constants[0].worldTransform = Matrix.identity()
    }

    return true // it's on
  }
}

//==============================================================================
// StandardRenderMode
// Base class for several different render modes.
//==============================================================================
class StandardRenderMode : RenderMode
{
  var firstColorIndex = 0
  var firstUVIndex    = 0

  init( _ renderer:Renderer, _ label:String )
  {
    super.init( renderer )

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
    vertexDescriptor.attributes[VertexAttribute.UV.rawValue].bufferIndex = VertexBufferIndex.meshUVs.rawValue

    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stride = 12
    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.positions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stride = 16
    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.colors.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    vertexDescriptor.layouts[VertexBufferIndex.meshUVs.rawValue].stride = 8
    vertexDescriptor.layouts[VertexBufferIndex.meshUVs.rawValue].stepRate = 1
    vertexDescriptor.layouts[VertexBufferIndex.meshUVs.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    //--------------------------------------------------------------------------
    // Pipeline
    //--------------------------------------------------------------------------
    do
    {
      let vertexFunction = renderer.shaderLibrary?.makeFunction(name:vertexShaderName())
      let fragmentFunction = renderer.shaderLibrary?.makeFunction(name:fragmentShaderName())
      let metalKitView = renderer.metalKitView

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.label = label
      pipelineDescriptor.sampleCount = metalKitView.sampleCount
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.vertexDescriptor = vertexDescriptor

      pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
      pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
      pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha
      pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
      pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipeline = try renderer.device.makeRenderPipelineState( descriptor:pipelineDescriptor )
    }
    catch
    {
      print("Unable to compile \(label) pipeline state: \(error)")
    }
  }

  func vertexShaderName()->String { return "solidColorVertexShader" }
  func fragmentShaderName()->String { return "solidColorFragmentShader" }

  override func activate( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.activate( renderEncoder )
    firstColorIndex = renderer.renderData.colorCount
    firstUVIndex    = renderer.renderData.uvCount
  }

  @discardableResult
  override func render( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if ( !super.render(renderEncoder) ) { return false }

    let renderData = renderer.renderData
    renderData.bindPositionBuffer( renderEncoder, firstPositionIndex, VertexBufferIndex.positions.rawValue )
    renderData.bindColorBuffer( renderEncoder, firstColorIndex, VertexBufferIndex.colors.rawValue )
    renderData.bindUVBuffer( renderEncoder, firstColorIndex, VertexBufferIndex.meshUVs.rawValue )
    renderData.bindConstantsBuffer( renderEncoder, VertexBufferIndex.constants.rawValue )

    return true
  }
}

//==============================================================================
// RenderModeDrawLines
//==============================================================================
class RenderModeDrawLines : StandardRenderMode
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

  @discardableResult
  override func render( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if ( !super.render(renderEncoder) ) { return false }

    let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:        MTLPrimitiveType.line,
      vertexStart: 0,
      vertexCount: count
    )

    return true
  }
}

//==============================================================================
// RenderModeFillSolidTriangles
//==============================================================================
class RenderModeFillSolidTriangles : StandardRenderMode
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

  @discardableResult
  override func render( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if ( !super.render(renderEncoder) ) { return false }

    let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:          MTLPrimitiveType.triangle,
      vertexStart:   0,
      vertexCount:   count
    )

    return true
  }
}

//==============================================================================
// RenderModeFillTexturedTriangles
//==============================================================================
class RenderModeFillTexturedTriangles : StandardRenderMode
{
  let verticesPerTriangle     = 3
  let positionValuesPerVertex = 3
  let colorValuesPerVertex    = 4
  let uvValuesPerVertex       = 5

  init( _ renderer:Renderer )
  {
    super.init( renderer, "FillTexturedTriangles" )
  }

  override func reserveCapacity( _ n:Int )
  {
    renderer.renderData.reservePositionCapacity( n * positionValuesPerVertex * verticesPerTriangle )
    renderer.renderData.reserveColorCapacity( n * colorValuesPerVertex * verticesPerTriangle )
    renderer.renderData.reserveUVCapacity( n * uvValuesPerVertex * verticesPerTriangle )
  }

  @discardableResult
  override func render( _ renderEncoder:MTLRenderCommandEncoder )->Bool
  {
    if ( !super.render(renderEncoder) ) { return false }
/*
    guard let texture = Plasmacore.singleton.texture else { return false }

    renderEncoder.setFragmentTexture( texture, index:TextureStage.color.rawValue )

    let count = (renderer.renderData.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:          MTLPrimitiveType.triangle,
      vertexStart:   0,
      vertexCount:   count
    )
 */

    return true
  }

  override func vertexShaderName()->String { return "textureVertexShader" }
  override func fragmentShaderName()->String { return "textureFragmentShader" }
}

