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
  var renderModeDrawLines             : RenderModeDrawLines?
  var renderModeFillSolidTriangles    : RenderModeFillSolidTriangles?
  var renderModeFillTexturedTriangles : RenderModeFillTexturedTriangles?

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
    renderModeDrawLines          = RenderModeDrawLines( self )
    renderModeFillSolidTriangles = RenderModeFillSolidTriangles( self )
    renderModeFillTexturedTriangles = RenderModeFillTexturedTriangles( self )
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
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushObjectTransform( m, replace )
                continue
              case .PUSH_ROTATE_OBJECT:
                let radians = q.readReal32()
                let axisX   = q.readReal32()
                let axisY   = q.readReal32()
                let axisZ   = q.readReal32()
                let replace = q.readLogical()
                renderData.pushObjectTransform( Matrix.rotate(radians,axisX,axisY,axisZ), replace )
                continue
              case .PUSH_TRANSLATE_OBJECT:
                let x = q.readReal32()
                let y = q.readReal32()
                let z = q.readReal32()
                let replace = q.readLogical()
                renderData.pushObjectTransform( Matrix.translate(x,y,z), replace )
                continue
              case .POP_OBJECT_TRANSFORM:
                renderData.popObjectTransform()
                continue
              case .PUSH_VIEW_TRANSFORM:
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushViewTransform( m, replace )
                continue
              case .PUSH_ROTATE_VIEW:
                let radians = q.readReal32()
                let axisX   = q.readReal32()
                let axisY   = q.readReal32()
                let axisZ   = q.readReal32()
                let replace = q.readLogical()
                renderData.pushViewTransform( Matrix.rotate(radians,axisX,axisY,axisZ), replace )
                continue
              case .PUSH_TRANSLATE_VIEW:
                let x = q.readReal32()
                let y = q.readReal32()
                let z = q.readReal32()
                let replace = q.readLogical()
                renderData.pushViewTransform( Matrix.translate(x,y,z), replace )
                continue
              case .POP_VIEW_TRANSFORM:
                renderData.popViewTransform()
                continue
              case .PUSH_PROJECTION_TRANSFORM:
                let m = q.readMatrix()
                let replace = q.readLogical()
                renderData.pushProjectionTransform( m, replace )
                continue
              case .PUSH_PERSPECTIVE_PROJECTION:
                let fovY = q.readReal32()
                let aspectRatio = q.readReal32()
                let zNear = q.readReal32()
                let zFar = q.readReal32()
                let replace = q.readLogical()
                renderData.pushProjectionTransform( Matrix.perspective(fovY,aspectRatio,zNear,zFar), replace )
                continue
              case .POP_PROJECTION_TRANSFORM:
                renderData.popProjectionTransform()
                continue
              case .BOX_FILL:
                renderModeFillSolidTriangles?.activate( renderEncoder )
                let x = q.readReal32()
                let y = q.readReal32()
                let w = q.readReal32()
                let h = q.readReal32()
                renderMode?.reserveCapacity( 2 )
                renderData.addPosition(   x,   y, 0 )
                renderData.addPosition( x+w, y+h, 0 )
                renderData.addPosition( x+w,   y, 0 )
                renderData.addPosition(   x,   y, 0 )
                renderData.addPosition(   x, y+h, 0 )
                renderData.addPosition( x+w, y+h, 0 )
                if (q.readByte() == 1)
                {
                  let color = q.readInt32()
                  for _ in 1...6 { renderData.addColor(color) }
                }
                else
                {
                  let c1 = q.readInt32()
                  let c2 = q.readInt32()
                  let c3 = q.readInt32()
                  let c4 = q.readInt32()
                  renderData.addColor( c1 )
                  renderData.addColor( c3 )
                  renderData.addColor( c2 )
                  renderData.addColor( c1 )
                  renderData.addColor( c4 )
                  renderData.addColor( c3 )
                }
                continue
              case .TRIANGLE_FILL:
                renderModeFillSolidTriangles?.activate( renderEncoder )
                renderMode?.reserveCapacity( 1 )
                for _ in 1...3
                {
                  let x = q.readReal32()
                  let y = q.readReal32()
                  renderData.addPosition( x, y, 0 )
                }
                if (q.readByte() == 1)
                {
                  let color = q.readInt32()
                  for _ in 1...3 { renderData.addColor(color) }
                }
                else
                {
                  let c1 = q.readInt32()
                  let c2 = q.readInt32()
                  let c3 = q.readInt32()
                  renderData.addColor( c1 )
                  renderData.addColor( c2 )
                  renderData.addColor( c3 )
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
        renderMode?.render( renderEncoder )

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
