enum RenderCmd : Int
{
  case END_RENDER
  case BEGIN_CANVAS                //( canvas_id:Int32X )
  case END_CANVAS
  case HEADER_CLEAR_COLOR          //( argb:Int32 )
  case HEADER_END
  case LOAD_TEXTURE                //( id:Int32X, filepath:String )
  case PUSH_OBJECT_TRANSFORM       //( transform:Real32[16], replace:Logical )
  case PUSH_ROTATE_OBJECT          //( [radians, axis_x, axis_y, axis_z]:Real32, replace:Logical )
  case PUSH_SCALE_OBJECT           //( [x,y,z]:Real32, replace:Logical )
  case PUSH_TRANSLATE_OBJECT       //( [x,y,z]:Real32, replace:Logical )
  case POP_OBJECT_TRANSFORM        //( count:Int32X )
  case PUSH_VIEW_TRANSFORM         //( transform:Real32[16], replace:Logical )
  case PUSH_ROTATE_VIEW            //( [radians, axis_x, axis_y, axis_z]:Real32, replace:Logical )
  case PUSH_SCALE_VIEW             //( [x,y,z]:Real32, replace:Logical )
  case PUSH_TRANSLATE_VIEW         //( [x,y,z]:Real32, replace:Logical )
  case POP_VIEW_TRANSFORM          //( count:Int32X )
  case PUSH_PROJECTION_TRANSFORM   //( transform:Real32[16], replace:Logical )
  case PUSH_PERSPECTIVE_PROJECTION //( [fov_y, aspect_ratio, z_near, z_far]:Real32, replace:Logical )
  case POP_PROJECTION_TRANSFORM    //( count:Int32X )
  case FILL_BOX                    //( [x,y,w,h,z]:Real32, color:Int32 )
  case FILL_BOX_MULTICOLOR         //( [x,y,w,h,z]:Real32, colors:Int32[4] )
  case FILL_TRIANGLE               //( [a,b,c]:XYZ32, color:Int32 )
  case FILL_TRIANGLE_MULTICOLOR    //( [a,b,c]:XYZ32, colors:Int32[3] )
  case DRAW_LINE                   //( [a,b]:XYZ32, [a_color,b_color]:Color )
  case DRAW_IMAGE                  //( [x,y,w,h,z]:Real32, color:Int32, [u1,v1,u2,v2]:Real32, texture_id:Int32X )
}
