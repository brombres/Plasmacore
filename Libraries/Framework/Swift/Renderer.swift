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

enum RendererError : Error
{
  case badVertexDescriptor
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

  var renderBuffer                 : RenderBuffer

  var isConfigured                 = false
  var renderModeDrawLines          : RenderModeDrawLines?
  var renderModeFillSolidTriangles : RenderModeFillSolidTriangles?

  var depthTestLT                  : MTLDepthStencilState

  // Display state
  var display_width  = 0
  var display_height = 0

  // Demo-specific assets
  var mesh     : MTKMesh?
  var colorMap : MTLTexture?

  init?( metalKitView:MTKView )
  {
    self.metalKitView = metalKitView
    metalKitView.preferredFramesPerSecond = 60

    self.device       = metalKitView.device!
    self.commandQueue = self.device.makeCommandQueue()!

    renderBuffer = RenderBuffer( device, maxBuffersInFlight )

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
    renderModeDrawLines          = RenderModeDrawLines( self )
    renderModeFillSolidTriangles = RenderModeFillSolidTriangles( self )
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

      renderBuffer.advanceFrame()

      return commandBuffer
    }
    else
    {
      return nil
    }
  }

  func draw(in view: MTKView)
  {
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

    renderBuffer.clearTransforms()

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
              case .PUSH_OBJECT_TRANSFORM:
                renderBuffer.pushObjectTransform( q.readMatrix() )
                continue
              case .POP_OBJECT_TRANSFORM:
                renderBuffer.popObjectTransform()
                continue
              case .PUSH_VIEW_TRANSFORM:
                renderBuffer.pushViewTransform( q.readMatrix() )
                continue
              case .POP_VIEW_TRANSFORM:
                renderBuffer.popViewTransform()
                continue
              case .PUSH_PROJECTION_TRANSFORM:
                renderBuffer.pushProjectionTransform( q.readMatrix() )
                continue
              case .POP_PROJECTION_TRANSFORM:
                renderBuffer.popProjectionTransform()
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
        // Triangle
        //----------------------------------------------------------------------
        if let renderMode = renderModeFillSolidTriangles
        {
          renderMode.activate()
          renderMode.reserveCapacity( 2 )

          renderBuffer.addPosition( -2.0,  0.5, 0 )
          renderBuffer.addPosition( -2.5, -0.5, 0 )
          renderBuffer.addPosition( -1.5, -0.5, 0 )

          renderBuffer.addPosition(  0.0,  0.5, 0 )
          renderBuffer.addPosition( -0.5, -0.5, 0 )
          renderBuffer.addPosition(  0.5, -0.5, 0 )

          renderBuffer.addColor( 1, 0, 0, 1 )
          renderBuffer.addColor( 0, 1, 0, 1 )
          renderBuffer.addColor( 0, 0, 1, 1 )

          renderBuffer.addColor( 1, 0, 0, 1 )
          renderBuffer.addColor( 1, 0, 0, 1 )
          renderBuffer.addColor( 1, 0, 0, 1 )
          //renderBuffer.addColor( 0xffFF0000 )
          //renderBuffer.addColor( 0xffFF0000 )
          //renderBuffer.addColor( 0xffFF0000 )

          renderMode.render( renderEncoder )
        }

        if let renderMode = renderModeDrawLines
        {
          renderMode.activate()
          renderMode.reserveCapacity( 6 )

          renderBuffer.addPosition( -2.0,  0.5, 0 )
          renderBuffer.addPosition( -2.5, -0.5, 0 )
          renderBuffer.addPosition( -2.5, -0.5, 0 )
          renderBuffer.addPosition( -1.5, -0.5, 0 )
          renderBuffer.addPosition( -1.5, -0.5, 0 )
          renderBuffer.addPosition( -2.0,  0.5, 0 )


          renderBuffer.addPosition(  0.0,  0.5, 0 )
          renderBuffer.addPosition( -0.5, -0.5, 0 )
          renderBuffer.addPosition( -0.5, -0.5, 0 )
          renderBuffer.addPosition(  0.5, -0.5, 0 )
          renderBuffer.addPosition(  0.5, -0.5, 0 )
          renderBuffer.addPosition(  0.0,  0.5, 0 )

          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )
          renderBuffer.addColor( 0xffFFFF00 )

          renderMode.render( renderEncoder )
        }

        //----------------------------------------------------------------------

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
