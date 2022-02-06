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
    firstPositionIndex = renderer.renderBuffer.positionCount
  }

  func reserveCapacity( _ n:Int )
  {
    preconditionFailure( "Override required." )
  }

  func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    preconditionFailure( "Override required." )
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
    firstColorIndex = renderer.renderBuffer.colorCount
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    renderEncoder.setRenderPipelineState( pipeline! )

    renderer.renderBuffer.bindPositionBuffer( renderEncoder, firstPositionIndex, ColoredBufferIndex.meshPositions.rawValue )
    renderer.renderBuffer.bindColorBuffer( renderEncoder, firstColorIndex, ColoredBufferIndex.meshGenerics.rawValue )
    renderer.renderBuffer.bindUniformsBuffer( renderEncoder, ColoredBufferIndex.uniforms.rawValue )
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
    renderer.renderBuffer.reservePositionCapacity( n * positionValuesPerVertex * verticesPerLine )
    renderer.renderBuffer.reserveColorCapacity( n * colorValuesPerVertex * verticesPerLine )
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.render( renderEncoder )

    let count = (renderer.renderBuffer.positionCount - firstPositionIndex) / positionValuesPerVertex
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
    renderer.renderBuffer.reservePositionCapacity( n * positionValuesPerVertex * verticesPerTriangle )
    renderer.renderBuffer.reserveColorCapacity( n * colorValuesPerVertex * verticesPerTriangle )
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    super.render( renderEncoder )

    let count = (renderer.renderBuffer.positionCount - firstPositionIndex) / positionValuesPerVertex
    renderEncoder.drawPrimitives(
      type:          MTLPrimitiveType.triangle,
      vertexStart:   0,
      vertexCount:   count
    )
  }
}

