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
      //my_function_which_takes_voidpointer_for_VkMetalSurfaceCreateInfoEXT(target);
      //CVDisplayLinkStop( displayLink )
      CubeInterface_render()
      return kCVReturnSuccess
    }

    if let layer = view.layer as? CAMetalLayer
    {
      NSLog( "Calling CubeInterface_configure()" )
      CubeInterface_configure( layer )
    }

		CVDisplayLinkCreateWithActiveCGDisplays( &display_link )
		CVDisplayLinkSetOutputCallback(
      display_link!,
      displayLinkOutputCallback,
      Unmanaged.passUnretained(view.layer!).toOpaque()
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
