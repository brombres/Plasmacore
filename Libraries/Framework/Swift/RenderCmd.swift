enum RenderCmd : Int
{
  case END_RENDER
  case BEGIN_CANVAS                //( canvas_id:Int32X )
  case END_CANVAS
  case HEADER_CLEAR_COLOR          //( argb:Int32 )
  case HEADER_END
  case PUSH_OBJECT_TRANSFORM       //( transform:Real32[16], replace:Logical )
  case PUSH_ROTATE_OBJECT          //( [radians, axis_x, axis_y, axis_z]:Real32, replace:Logical )
  case PUSH_TRANSLATE_OBJECT       //( x, y, z : Real32, replace:Logical )
  case POP_OBJECT_TRANSFORM
  case PUSH_VIEW_TRANSFORM         //( transform:Real32[16], replace:Logical )
  case PUSH_ROTATE_VIEW            //( [radians, axis_x, axis_y, axis_z]:Real32, replace:Logical )
  case PUSH_TRANSLATE_VIEW         //( x, y, z : Real32, replace:Logical )
  case POP_VIEW_TRANSFORM
  case PUSH_PROJECTION_TRANSFORM   //( transform:Real32[16], replace:Logical )
  case PUSH_PERSPECTIVE_PROJECTION //( [fov_y, aspect_ratio, z_near, z_far]:Real32, replace:Logical )
  case POP_PROJECTION_TRANSFORM
}
