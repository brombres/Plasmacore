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
    return layer
  }

  override func viewDidChangeBackingProperties()
  {
    self.layer!.contentsScale = self.window!.backingScaleFactor
  }
}
