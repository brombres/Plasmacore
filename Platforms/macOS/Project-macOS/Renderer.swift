//
//  Renderer.swift
//  Project-macOS
//
//  Created by Abe Pralle on 1/28/22.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100
// The 256 byte aligned size of our uniform structure.
// "Uniforms" are shader variables that remain constant for a given render batch
// such as projectionTransform and worldTransform.

let maxBuffersInFlight = 3
// The maximum number of MTLCommandBuffers (AKA frame renders) that can
// be queued for rendering.

enum RendererError : Error {
  case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate
{
  public let device        : MTLDevice

  let commandQueue         : MTLCommandQueue
  // A queue of MTLCommandBuffers for rendering. Each MTLCommandBuffer will render
  // possibly multiple passes to a single target drawable such as the MTKView or an
  // offscreen texture.

  let inFlightSemaphore    = DispatchSemaphore(value:maxBuffersInFlight)
  // A DispatchSemaphore is a synchronized counter. In this case it is used to
  // limit the number of queued or in-progress command buffers / render batches /
  // "frames". To render a batch we call:
  //
  //   inFlightSemaphore.wait()
  //   ...
  //   inFlightSemaphore.signal()
  //
  // The wait() call will decrement the counter and continue. It blocks if 3
  // batches have called wait() before any of them call signal(); as soon as
  // one batch finishes and calls signal() than the blocked wait() returns.

  var dynamicUniformBuffer : MTLBuffer
  var uniformBufferOffset  = 0
  var uniformBufferIndex   = 0
  var uniforms             : UnsafeMutablePointer<Uniforms>
  // dynamicUniformBuffer
  //   Three sets of transform matrices for our max of three concurrent batches
  //
  // uniformBufferIndex
  //   0..2 - the index of the current batch uniform data.
  //
  // uniformBufferOffset
  //   The byte offset of the current batch uniform data.
  //
  // uniforms
  //   A pointer to the current batch uniforms.

  var texturedVertexDescriptor : MTLVertexDescriptor
  var texturedPipeline         : MTLRenderPipelineState

  var coloredVertexDescriptor  : MTLVertexDescriptor
  var coloredPipeline          : MTLRenderPipelineState

  var depthTestLT              : MTLDepthStencilState

  // Display state
  var display_width  = 0
  var display_height = 0
  var clear_color    = 0

  var projectionTransform:matrix_float4x4 = matrix_float4x4()
  var objectTransform:matrix_float4x4 = matrix_float4x4()
  var viewTransform:matrix_float4x4 = matrix_float4x4()

  // Demo-specific assets
  var mesh     : MTKMesh?
  var colorMap : MTLTexture?

  var positionBuffer : MTLBuffer
  var colorBuffer    : MTLBuffer
  var uvBuffer       : MTLBuffer

  init?( metalKitView:MTKView )
  {
    metalKitView.preferredFramesPerSecond = 60

    self.device       = metalKitView.device!
    self.commandQueue = self.device.makeCommandQueue()!

    let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

    self.dynamicUniformBuffer = self.device.makeBuffer(
      length:uniformBufferSize,
      options:[MTLResourceOptions.storageModeShared]
    )!

    self.dynamicUniformBuffer.label = "UniformBuffer"

    uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

    metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
    metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    metalKitView.sampleCount = 1

    texturedVertexDescriptor = Renderer.buildTexturedVertexDescriptor()
    coloredVertexDescriptor = Renderer.buildColoredVertexDescriptor()

    do
    {
      let library = device.makeDefaultLibrary()
      texturedPipeline = try Renderer.buildTexturedPipeline(device:device, metalKitView:metalKitView,
          shaderLibrary:library, texturedVertexDescriptor:texturedVertexDescriptor)
      coloredPipeline = try Renderer.buildColoredPipeline(device: device, metalKitView: metalKitView,
          shaderLibrary:library, coloredVertexDescriptor:coloredVertexDescriptor)
    }
    catch
    {
      print("Unable to compile render pipeline state.  Error info: \(error)")
        return nil
    }

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = true
    self.depthTestLT = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

    let positions:[Float] =
    [
       0.0,  0.5, 0,
      -0.5, -0.5, 0,
       0.5, -0.5, 0
    ]
    let colors:[Float] =
    [
      1, 0, 0, 1,
      0, 1, 0, 1,
      0, 0, 1, 1
    ]
    let uv:[Float] =
    [
      0, 0,
      1, 0,
      0, 1
    ]

    self.positionBuffer = self.device.makeBuffer( bytes:positions, length:(9*4), options:[MTLResourceOptions.storageModeShared] )!
    self.colorBuffer = self.device.makeBuffer( bytes:colors, length:(12*4), options:[MTLResourceOptions.storageModeShared] )!
    self.uvBuffer = self.device.makeBuffer( bytes:uv, length:(6*4), options:[MTLResourceOptions.storageModeShared] )!
                                                  //options:MTLResourceOptionCPUCacheModeDefault];

    super.init()
  }

  class func buildTexturedVertexDescriptor() -> MTLVertexDescriptor
  {
    // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
    //   pipeline and how we'll layout our Model IO vertices

    let texturedVertexDescriptor = MTLVertexDescriptor()

    texturedVertexDescriptor.attributes[TexturedVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    texturedVertexDescriptor.attributes[TexturedVertexAttribute.position.rawValue].offset = 0
    texturedVertexDescriptor.attributes[TexturedVertexAttribute.position.rawValue].bufferIndex = TexturedBufferIndex.meshPositions.rawValue

    texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
    texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].offset = 0
    texturedVertexDescriptor.attributes[TexturedVertexAttribute.texcoord.rawValue].bufferIndex = TexturedBufferIndex.meshGenerics.rawValue

    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshPositions.rawValue].stride = 12
    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshPositions.rawValue].stepRate = 1
    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stride = 8
    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stepRate = 1
    texturedVertexDescriptor.layouts[TexturedBufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    return texturedVertexDescriptor
  }

  class func buildColoredVertexDescriptor() -> MTLVertexDescriptor
  {
    let coloredVertexDescriptor = MTLVertexDescriptor()

    coloredVertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    coloredVertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].offset = 0
    coloredVertexDescriptor.attributes[ColoredVertexAttribute.position.rawValue].bufferIndex = ColoredBufferIndex.meshPositions.rawValue

    coloredVertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
    coloredVertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].offset = 0
    coloredVertexDescriptor.attributes[ColoredVertexAttribute.color.rawValue].bufferIndex = ColoredBufferIndex.meshGenerics.rawValue

    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stride = 12
    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stepRate = 1
    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stride = 16
    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stepRate = 1
    coloredVertexDescriptor.layouts[ColoredBufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    return coloredVertexDescriptor
  }

  class func buildTexturedPipeline( device:MTLDevice, metalKitView:MTKView,
      shaderLibrary:MTLLibrary?, texturedVertexDescriptor:MTLVertexDescriptor )
      throws -> MTLRenderPipelineState
  {
    let vertexFunction = shaderLibrary?.makeFunction(name: "texturedVertexShader")
    let fragmentFunction = shaderLibrary?.makeFunction(name: "texturedFragmentShader")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "RenderPipeline"
    pipelineDescriptor.sampleCount = metalKitView.sampleCount
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = texturedVertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
    pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }

  class func buildColoredPipeline( device:MTLDevice, metalKitView:MTKView,
      shaderLibrary:MTLLibrary?, coloredVertexDescriptor:MTLVertexDescriptor)
      throws -> MTLRenderPipelineState
  {
    let vertexFunction = shaderLibrary?.makeFunction(name: "coloredVertexShader")
    let fragmentFunction = shaderLibrary?.makeFunction(name: "coloredFragmentShader")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "RenderPipeline"
    pipelineDescriptor.sampleCount = metalKitView.sampleCount
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = coloredVertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
    pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }

  func prepareDemoAssets()
  {
    do
    {
      mesh = try Renderer.buildMesh(device: device, texturedVertexDescriptor: texturedVertexDescriptor)
    }
    catch
    {
      print("Unable to build MetalKit Mesh. Error info: \(error)")
      return
    }

    do
    {
      colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
    }
    catch
    {
      print("Unable to load texture. Error info: \(error)")
      return
    }
  }

  class func buildMesh( device:MTLDevice, texturedVertexDescriptor:MTLVertexDescriptor) throws -> MTKMesh
  {
    /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
    let metalAllocator = MTKMeshBufferAllocator(device: device)
    let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
        segments: SIMD3<UInt32>(2, 2, 2),
        geometryType: MDLGeometryType.triangles,
        inwardNormals:false,
        allocator: metalAllocator)

    let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(texturedVertexDescriptor)

    guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else
    {
      throw RendererError.badVertexDescriptor
    }
    attributes[TexturedVertexAttribute.position.rawValue].name = MDLVertexAttributePosition
    attributes[TexturedVertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

    mdlMesh.vertexDescriptor = mdlVertexDescriptor

    return try MTKMesh(mesh:mdlMesh, device:device)
  }

  class func loadTexture(device: MTLDevice,
      textureName: String) throws -> MTLTexture
  {
    /// Load texture data with optimal parameters for sampling
    let textureLoader = MTKTextureLoader(device: device)

    let textureLoaderOptions =
    [
      MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
      MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
    ]

    return try textureLoader.newTexture(
      name        : textureName,
      scaleFactor : 1.0,
      bundle      : nil,
      options     : textureLoaderOptions
    )
  }

  private func rogueRender()
  {
    let m = PlasmacoreMessage( "Display.render" )
    m.writeInt32X( display_width )
    m.writeInt32X( display_height )
    if let q = m.send()
    {
      while (true)
      {
        let opcode = q.readInt32X()
        if let cmd = RenderCmd( rawValue:opcode )
        {
          switch (cmd)
          {
            case .END:
              break
            case .CLEAR_COLOR:
              clear_color = q.readInt32()
              continue
            case .PUSH_OBJECT_TRANSFORM:
              objectTransform = q.readMatrix()
              continue
            case .POP_OBJECT_TRANSFORM:
              continue  // TODO
            case .PUSH_VIEW_TRANSFORM:
              viewTransform = q.readMatrix()
              continue
            case .POP_VIEW_TRANSFORM:
              continue  // TODO
            case .PUSH_PROJECTION_TRANSFORM:
              projectionTransform = q.readMatrix()
              continue
            case .POP_PROJECTION_TRANSFORM:
              continue  // TODO
          }
          break  // END
        }
        else
        {
          print( "[ERROR] Unhandled RenderCmd" )
        }
      }
    }
  }

  func makeCommandBuffer()->MTLCommandBuffer?
  {
    _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

    if let commandBuffer = commandQueue.makeCommandBuffer()
    {
      let semaphore = inFlightSemaphore
      commandBuffer.addCompletedHandler
      {
        (_ commandBuffer)-> Swift.Void in
          semaphore.signal()
      }

      uniformBufferIndex  = (uniformBufferIndex + 1) % maxBuffersInFlight
      uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
      uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

      return commandBuffer
    }
    else
    {
      return nil
    }
  }

  func draw(in view: MTKView)
  {
    rogueRender()

    renderView( view )
    Plasmacore.singleton.collect_garbage()
  }

  func renderView( _ view:MTKView )
  {
    guard let commandBuffer = makeCommandBuffer() else { return }

    if (mesh == nil)
    {
      // Better to check a flag and see if we've already tried to load the assets, but these
      // demo assets will be going away soon anyhow.
      prepareDemoAssets()
    }

    uniforms[0].projectionTransform = projectionTransform
    uniforms[0].worldTransform = simd_mul(viewTransform, objectTransform)

    /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
    let renderPass = view.currentRenderPassDescriptor

    if let renderPass = renderPass
    {
      let bg = UInt( clear_color )
      let bg_r = Double( (bg >> 16) & 255 ) / 255.0
      let bg_g = Double( (bg >> 8)  & 255 ) / 255.0
      let bg_b = Double(  bg        & 255 ) / 255.0
      let bg_a = Double( (bg >> 24) & 255 ) / 255.0
      renderPass.colorAttachments[0].clearColor = MTLClearColorMake( bg_r, bg_g, bg_b, bg_a )

      /// Final pass rendering code here
      if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
      {
        renderEncoder.label = "Primary Render Encoder"
        renderEncoder.pushDebugGroup("Draw Box")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setDepthStencilState(depthTestLT)

        //----------------------------------------------------------------------
        // Cube
        //----------------------------------------------------------------------
        renderEncoder.setRenderPipelineState(texturedPipeline)
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: TexturedBufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: TexturedBufferIndex.uniforms.rawValue)

        for (index, element) in mesh!.vertexDescriptor.layouts.enumerated()
        {
          guard let layout = element as? MDLVertexBufferLayout else { return }
          if layout.stride != 0
          {
            let buffer = mesh!.vertexBuffers[index]
            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
          }
        }

        renderEncoder.setFragmentTexture(colorMap!, index:TextureIndex.color.rawValue)

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

        //----------------------------------------------------------------------
        // Triangle
        //----------------------------------------------------------------------
        renderEncoder.setRenderPipelineState(coloredPipeline)
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: ColoredBufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: ColoredBufferIndex.uniforms.rawValue)

        renderEncoder.setVertexBuffer( positionBuffer, offset:0, index:ColoredBufferIndex.meshPositions.rawValue )
        renderEncoder.setVertexBuffer( colorBuffer,    offset:0, index:ColoredBufferIndex.meshGenerics.rawValue )

        //renderEncoder.setFragmentTexture(colorMap!, index:TextureIndex.color.rawValue)

        renderEncoder.drawPrimitives(
          type:          MTLPrimitiveType.triangle,
          vertexStart:   0,
          vertexCount:   3,
          instanceCount: 1
        )

        //----------------------------------------------------------------------

        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()

        if let drawable = view.currentDrawable
        {
          commandBuffer.present(drawable)
        }
      }
    }
    commandBuffer.commit()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
  {
    /// Respond to drawable size or orientation changes here
    display_width  = Int(size.width)
    display_height = Int(size.height)
  }
}

