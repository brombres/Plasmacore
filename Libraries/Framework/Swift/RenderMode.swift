class RenderMode
{
  let renderer : Renderer

  init( _ renderer:Renderer )
  {
    self.renderer = renderer
  }

  func ensureCapacity( _ n:Int )
  {
    preconditionFailure( "Override required." )
  }

  func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    preconditionFailure( "Override required." )
  }
}

class RenderModeFillShape : RenderMode
{
  let vertexDescriptor : MTLVertexDescriptor
  var pipeline         : MTLRenderPipelineState?

  override init( _ renderer:Renderer )
  {
    //--------------------------------------------------------------------------
    // Vertex Descriptor
    //--------------------------------------------------------------------------
    vertexDescriptor = MTLVertexDescriptor()

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
      pipelineDescriptor.label = "RenderPipeline"
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
      print("Unable to compile RenderModeFillShape pipeline state: \(error)")
    }

    super.init( renderer )
  }

  override func ensureCapacity( _ n:Int )
  {
    renderer.renderBuffer.ensurePositionCapacity( n*3 )
    renderer.renderBuffer.ensureColorCapacity( n*4 )
  }

  override func render( _ renderEncoder:MTLRenderCommandEncoder )
  {
    renderEncoder.setRenderPipelineState( pipeline! )

    renderEncoder.setVertexBuffer(
      renderer.dynamicUniformBuffer,
      offset: renderer.uniformBufferOffset,
      index:  ColoredBufferIndex.uniforms.rawValue
    )
    renderEncoder.setFragmentBuffer(
      renderer.dynamicUniformBuffer,
      offset: renderer.uniformBufferOffset,
      index:  ColoredBufferIndex.uniforms.rawValue
    )

    renderer.renderBuffer.bindPositionBuffer( renderEncoder, ColoredBufferIndex.meshPositions.rawValue )
    renderer.renderBuffer.bindColorBuffer( renderEncoder, ColoredBufferIndex.meshGenerics.rawValue )

    renderEncoder.drawPrimitives(
      type:          MTLPrimitiveType.triangle,
      vertexStart:   0,
      vertexCount:   renderer.renderBuffer.positionCount
    )
  }
}

