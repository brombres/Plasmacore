enum RenderCmd : Int
{
  case END_RENDER
  case BEGIN_CANVAS                //( canvas_id:Int32X )
  case END_CANVAS
  case HEADER_CLEAR_COLOR          //( argb:Int32 )
  case HEADER_END
  case PUSH_OBJECT_TRANSFORM
  case PUSH_ROTATE_OBJECT          //( radians, axis_x, axis_y, axis_z : Real32 )
  case PUSH_TRANSLATE_OBJECT
  case POP_OBJECT_TRANSFORM
  case PUSH_VIEW_TRANSFORM
  case PUSH_ROTATE_VIEW            //( radians, axis_x, axis_y, axis_z : Real32 )
  case PUSH_TRANSLATE_VIEW
  case POP_VIEW_TRANSFORM
  case PUSH_PROJECTION_TRANSFORM
  case PUSH_PERSPECTIVE_PROJECTION // ( fov_y:Real32, aspect_ratio:Real32, z_near:Real32, z_far:Real32 )
  case POP_PROJECTION_TRANSFORM
}
