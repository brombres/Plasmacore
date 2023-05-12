// GameViewController.swift
// Project-macOS
//
// Created by Abe Pralle on 4/14/23.
//
// References used:
//   https://www.reddit.com/r/vulkan/comments/d61wnd/moltenvk_with_swift/
//   https://stackoverflow.com/questions/25981553/cvdisplaylink-with-swift

import Cocoa

// Our macOS specific view controller
class PlasmacoreViewController : NSViewController
{
  var display_link : CVDisplayLink?

	override func viewDidLoad()
  {
		super.viewDidLoad()

		view.wantsLayer = true

    let displayLinkOutputCallback:CVDisplayLinkOutputCallback =
    {
      (displayLink:CVDisplayLink, inNow:UnsafePointer<CVTimeStamp>, inOutputTime:UnsafePointer<CVTimeStamp>,
          flagsIn:CVOptionFlags, flagsOut:UnsafeMutablePointer<CVOptionFlags>,
          displayLinkContext:UnsafeMutableRawPointer?) -> CVReturn in

      guard let view_pointer = displayLinkContext else { return kCVReturnSuccess }
      let view = unsafeBitCast( view_pointer, to:PlasmacoreViewController.self )
      objc_sync_enter( view ); defer { objc_sync_exit(view) }   // @synchronized (view)

      DispatchQueue.main.async
      {
        CubeInterface_render()
      }
      return kCVReturnSuccess
    }

    if let layer = view.layer as? CAMetalLayer
    {
      NSLog( "Calling Plasmacore.configureRenderer()" )
      Plasmacore.singleton.configureRenderer( layer:layer )
      NSLog( "Calling CubeInterface_configure()" )
      CubeInterface_configure()
    }

		CVDisplayLinkCreateWithActiveCGDisplays( &display_link )

		CVDisplayLinkSetOutputCallback(
      display_link!,
      displayLinkOutputCallback,
      Unmanaged.passUnretained(view).toOpaque()
    )
		CVDisplayLinkStart( display_link! )
	}

  deinit
  {
    //CVDisplayLinkStop( display_link )
  }

	override var representedObject: Any?
  {
		didSet
    {
		  // Update the view, if already loaded.
		}
	}
}
