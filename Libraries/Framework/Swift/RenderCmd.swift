enum RenderCmd : Int
{
  case END_RENDER
  case BEGIN_CANVAS               //( canvas_id:Int32X )
  case END_CANVAS
  case HEADER_CLEAR_COLOR         //( argb:Int32 )
  case HEADER_END
  case PUSH_OBJECT_TRANSFORM
  case POP_OBJECT_TRANSFORM
  case PUSH_VIEW_TRANSFORM
  case POP_VIEW_TRANSFORM
  case PUSH_PROJECTION_TRANSFORM
  case POP_PROJECTION_TRANSFORM
}
