import Cocoa

class PlasmacoreView : NSView
{
  override var wantsUpdateLayer:Bool
  {
    get { return true }
  }

  override func makeBackingLayer()->CALayer
  {
    let layer = CAMetalLayer()
    layer.contentsScale = NSScreen.main!.backingScaleFactor
    return layer
  }

  //override func setFrameSize(_ newSize: NSSize)
  //{
  //    super.setFrameSize(newSize)
  //}

  override func viewDidChangeBackingProperties()
  {
    self.layer!.contentsScale = self.window!.backingScaleFactor
  }
}
