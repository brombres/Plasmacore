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

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError : Error {
  case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate
{
  public let device        : MTLDevice
  let commandQueue         : MTLCommandQueue
  var dynamicUniformBuffer : MTLBuffer
  var pipelineState        : MTLRenderPipelineState
  var depthState           : MTLDepthStencilState
  var colorMap             : MTLTexture

  let inFlightSemaphore    = DispatchSemaphore(value: maxBuffersInFlight)
  var uniformBufferOffset  = 0
  var uniformBufferIndex   = 0
  var uniforms             : UnsafeMutablePointer<Uniforms>

  var projectionMatrix     : matrix_float4x4 = matrix_float4x4()
  var display_width        = 0
  var display_height       = 0
  var clear_color          = 0

  //var rotation: Float = 0

  var mesh : MTKMesh

  init?( metalKitView:MTKView )
  {
    self.device       = metalKitView.device!
    self.commandQueue = self.device.makeCommandQueue()!

    metalKitView.preferredFramesPerSecond = 60

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

    let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()

    do
    {
      pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device, metalKitView: metalKitView,
          mtlVertexDescriptor: mtlVertexDescriptor)
    }
    catch
    {
      print("Unable to compile render pipeline state.  Error info: \(error)")
        return nil
    }

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = true
    self.depthState = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

    do
    {
      mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
    }
    catch
    {
      print("Unable to build MetalKit Mesh. Error info: \(error)")
        return nil
    }

    do
    {
      colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
    }
    catch
    {
      print("Unable to load texture. Error info: \(error)")
        return nil
    }

    super.init()
  }

  class func buildMetalVertexDescriptor() -> MTLVertexDescriptor
  {
    // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
    //   pipeline and how we'll layout our Model IO vertices

    let mtlVertexDescriptor = MTLVertexDescriptor()

    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

    return mtlVertexDescriptor
  }

  class func buildRenderPipelineWithDevice( device:MTLDevice, metalKitView:MTKView,
      mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState
  {
    /// Build a render state pipeline object

    let library = device.makeDefaultLibrary()

      let vertexFunction = library?.makeFunction(name: "vertexShader")
      let fragmentFunction = library?.makeFunction(name: "fragmentShader")

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.label = "RenderPipeline"
      pipelineDescriptor.sampleCount = metalKitView.sampleCount
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

      pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
      pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
      pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

      return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }

  class func buildMesh( device:MTLDevice, mtlVertexDescriptor:MTLVertexDescriptor) throws -> MTKMesh
  {
    /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
    let metalAllocator = MTKMeshBufferAllocator(device: device)
    let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
        segments: SIMD3<UInt32>(2, 2, 2),
        geometryType: MDLGeometryType.triangles,
        inwardNormals:false,
        allocator: metalAllocator)

    let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

    guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else
    {
      throw RendererError.badVertexDescriptor
    }
    attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
    attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

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

  private func updateDynamicBufferState()
  {
    /// Update the state of our uniform buffers before rendering

    uniformBufferIndex  = (uniformBufferIndex + 1) % maxBuffersInFlight
    uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
    uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
  }

  private func rogueRender()
  {
    /// Update any game state before rendering
    uniforms[0].projectionMatrix = projectionMatrix

    var modelMatrix:matrix_float4x4 = matrix_float4x4()
    var viewMatrix:matrix_float4x4 = matrix_float4x4()

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
              modelMatrix = q.readMatrix()
              continue
            case .POP_OBJECT_TRANSFORM:
              continue  // TODO
            case .PUSH_VIEW_TRANSFORM:
              viewMatrix = q.readMatrix()
              continue
            case .POP_VIEW_TRANSFORM:
              continue  // TODO
            case .PUSH_PROJECTION_TRANSFORM:
              projectionMatrix = q.readMatrix()
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

    uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
  }

  func draw(in view: MTKView)
  {
    /// Per frame updates hare
    _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

    if let commandBuffer = commandQueue.makeCommandBuffer()
    {
      let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler
        {
          (_ commandBuffer)-> Swift.Void in
            semaphore.signal()
        }

      self.updateDynamicBufferState()
      self.rogueRender()

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
          renderEncoder.setRenderPipelineState(pipelineState)
          renderEncoder.setDepthStencilState(depthState)
          renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
          renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)

          for (index, element) in mesh.vertexDescriptor.layouts.enumerated()
          {
            guard let layout = element as? MDLVertexBufferLayout else { return }
            if layout.stride != 0
            {
              let buffer = mesh.vertexBuffers[index]
              renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
            }
          }

          renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)

          for submesh in mesh.submeshes
          {
            renderEncoder.drawIndexedPrimitives(
              type: submesh.primitiveType,
              indexCount: submesh.indexCount,
              indexType: submesh.indexType,
              indexBuffer: submesh.indexBuffer.buffer,
              indexBufferOffset: submesh.indexBuffer.offset
            )
          }

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
    Plasmacore.singleton.collect_garbage()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
  {
    /// Respond to drawable size or orientation changes here
    display_width  = Int(size.width)
    display_height = Int(size.height)
  }
}

