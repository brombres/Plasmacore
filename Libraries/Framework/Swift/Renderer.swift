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

let maxBuffersInFlight = 3
// The maximum number of MTLCommandBuffers (AKA frame renders) that can
// be queued for rendering.

enum PlasmacoreError : Error
{
  case runtimeError(String)
}

class Renderer: NSObject, MTKViewDelegate
{
  public let device        : MTLDevice
  public let metalKitView  : MTKView

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

  public let shaderLibrary : MTLLibrary?

  var renderData                 : RenderData

  var isConfigured                    = false
  var renderMode                      : RenderMode?

  var depthTestLT                  : MTLDepthStencilState

  // Display state
  var display_width  = 0
  var display_height = 0

  init?( metalKitView:MTKView )
  {
    self.metalKitView = metalKitView
    metalKitView.preferredFramesPerSecond = 60

    self.device       = metalKitView.device!
    self.commandQueue = self.device.makeCommandQueue()!

    renderData = RenderData( device, maxBuffersInFlight )

    metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
    metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    metalKitView.sampleCount = 1

    shaderLibrary = device.makeDefaultLibrary()

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.always
    depthStateDescriptor.isDepthWriteEnabled = true
    self.depthTestLT = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

    super.init()
  }

  func configure()
  {
    if (isConfigured) { return }
    isConfigured = true
  }

  private func rogueRender()->PlasmacoreMessage?
  {
    let m = PlasmacoreMessage( "Display.render" )
    m.writeInt32X( 0 )  // display_id
    m.writeInt32X( display_width )
    m.writeInt32X( display_height )
    return m.send()
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

      renderData.advanceFrame()

      return commandBuffer
    }
    else
    {
      return nil
    }
  }

  func draw(in view: MTKView)
  {
    Plasmacore.singleton.currentMetalDevice = device

    configure()

    guard let q = rogueRender() else { return }

    guard let commandBuffer = makeCommandBuffer() else { return }

    while (true)
    {
      let opcode = q.readInt32X()
      //print( "\(RenderCmd(rawValue:opcode)!)" )
      if let cmd = RenderCmd( rawValue:opcode )
      {
        switch (cmd)
        {
          case .END_RENDER:
            break
          case .BEGIN_CANVAS:
            let canvasID = q.readInt32X()
            let byteSize = q.readInt32()
            if (canvasID != 0)
            {
              print( "[TODO] Render offscreen canvas" )
              q.skip( byteSize )
              continue
            }
            else
            {
              renderCanvas( view, q, canvasID, commandBuffer )
            }
          default:
            print( "[ERROR] Unexpected render queue command \(RenderCmd(rawValue:opcode)!)" )
        }
        break  // END
      }
      else
      {
        print( "[ERROR] Unhandled RenderCmd \(opcode)" )
      }
    }

    if let drawable = view.currentDrawable
    {
      commandBuffer.present(drawable)
    }
    commandBuffer.commit()

    Plasmacore.singleton.collect_garbage()
  }

  func renderCanvas( _ view:MTKView, _ q:PlasmacoreMessage, _ canvasID:Int, _ commandBuffer:MTLCommandBuffer )
  {
    var clearColor = 0

    // Process render queue header
    while (true)
    {
      let opcode = q.readInt32X()
      //print( "\(RenderCmd(rawValue:opcode)!)" )
      if let cmd = RenderCmd( rawValue:opcode )
      {
        switch (cmd)
        {
          case .HEADER_CLEAR_COLOR:
            clearColor = q.readInt32()
            continue
          case .HEADER_END:
            break
          default:
            print( "[ERROR] Unexpected render queue header command \(RenderCmd(rawValue:opcode)!)" )
        }
        break  // END
      }
      else
      {
        print( "[ERROR] Unhandled RenderCmd \(opcode)" )
      }
    }

    renderData.clearTransforms()
    renderMode = nil

    /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
    let renderPass = view.currentRenderPassDescriptor

    if let renderPass = renderPass
    {
      let bg = UInt( clearColor )
      let bg_r = Double( (bg >> 16) & 255 ) / 255.0
      let bg_g = Double( (bg >> 8)  & 255 ) / 255.0
      let bg_b = Double(  bg        & 255 ) / 255.0
      let bg_a = Double( (bg >> 24) & 255 ) / 255.0
      renderPass.colorAttachments[0].clearColor = MTLClearColorMake( bg_r, bg_g, bg_b, bg_a )

      /// Final pass rendering code here
      if let renderEncoder = commandBuffer.makeRenderCommandEncoder( descriptor:renderPass )
      {
        renderEncoder.label = "Canvas \(canvasID) Render Encoder"
        //renderEncoder.pushDebugGroup("Draw Box")
        renderEncoder.setCullMode(.back)
        //renderEncoder.setCullMode(.none)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setDepthStencilState(depthTestLT)

        while (true)
        {
          let opcode = q.readInt32X()
          //print( "\(RenderCmd(rawValue:opcode)!)" )
          if let cmd = RenderCmd( rawValue:opcode )
          {
            switch (cmd)
            {
              case .END_CANVAS:
                break
              case .LOAD_TEXTURE:
                let textureID = q.readInt32X()
                let filepath  = q.readString()
                PlasmacoreUtility.loadTexture( textureID, filepath )
                continue
              case .PUSH_OBJECT_TRANSFORM:
                renderMode?.render()
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushObjectTransform( m, replace )
                continue
              case .POP_OBJECT_TRANSFORM:
                renderMode?.render()
                renderData.popObjectTransform( q.readInt32X() )
                continue
              case .PUSH_VIEW_TRANSFORM:
                renderMode?.render()
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushViewTransform( m, replace )
                continue
              case .POP_VIEW_TRANSFORM:
                renderMode?.render()
                renderData.popViewTransform( q.readInt32X() )
                continue
              case .PUSH_PROJECTION_TRANSFORM:
                renderMode?.render()
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushProjectionTransform( m, replace )
                continue
              case .POP_PROJECTION_TRANSFORM:
                renderMode?.render()
                renderData.popProjectionTransform( q.readInt32X() )
                continue
              case .DEFINE_RENDER_MODE:
                //( [id,shape]:Int32X,[src_blend,dest_blend]:BlendFactor, [vertex_shader,fragment_shader]:String )
                let renderModeID = q.readInt32X()
                let shape = q.readInt32X()
                let srcBlend = q.readBlendFactor()
                let destBlend = q.readBlendFactor()
                let vertexShader = q.readString()
                let fragmentShader = q.readString()
                let mode = RenderMode( self, renderModeID, shape, srcBlend, destBlend, vertexShader, fragmentShader )
                Plasmacore.singleton.renderModes[renderModeID] = mode
                continue
              case .USE_RENDER_MODE:
                //( id:Int32X )
                let renderModeID = q.readInt32X()
                if let mode = Plasmacore.singleton.renderModes[renderModeID]
                {
                  mode.activate( renderEncoder )
                }
                continue
              case .PUSH_POSITIONS:
                // ( count:Int32X, positions:XYZ32[count] )
                let count = q.readInt32X()
                renderData.reservePositionCapacity( count*3 )
                for _ in 1...count
                {
                  let x = q.readReal32()
                  let y = q.readReal32()
                  let z = q.readReal32()
                  renderData.addPosition( x, y, z )
                }
                continue
              case .PUSH_COLORS:
                //( count:Int32X, colors:Int32[count] )
                let count = q.readInt32X()
                renderData.reserveColorCapacity( count*4 )
                for _ in 1...count { renderData.addColor(q.readInt32()) }
                continue
              case .PUSH_UVS:
                //( count:Int32X, positions:XY32[count] )
                let count = q.readInt32X()
                renderData.reserveUVCapacity( count*2 )
                for _ in 1...count
                {
                  let u = q.readReal32()
                  let v = q.readReal32()
                  renderData.addUV( u, v )
                }
                continue
              case .USE_TEXTURE:
                let textureID = q.readInt32X()
                if let texture = Plasmacore.singleton.textures[textureID]
                {
                  renderMode?.setTexture( texture )
                }
                continue
              default:
                print( "[ERROR] Unexpected render queue command \(RenderCmd(rawValue:opcode)!)" )
            }
            break  // END
          }
          else
          {
            print( "[ERROR] Unhandled RenderCmd \(opcode)" )
          }
        }

        //----------------------------------------------------------------------
        renderMode?.render()

        //renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
      }
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
  {
    /// Respond to drawable size or orientation changes here
    display_width  = Int(size.width)
    display_height = Int(size.height)
  }
}
