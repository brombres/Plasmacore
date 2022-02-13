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
  case DEFINE_RENDER_MODE          //( [id,shape]:Int32X, [src_blend,dest_blend]:BlendFactor, [vertex_shader,fragment_shader]:String )
  case USE_RENDER_MODE             //( id:Int32X )
  case PUSH_POSITIONS              //( count:Int32X, positions:XYZ32[count] )
  case PUSH_COLORS                 //( count:Int32X, colors:Int32[count] )
  case PUSH_UVS                    //( count:Int32X, positions:XY32[count] )
}
