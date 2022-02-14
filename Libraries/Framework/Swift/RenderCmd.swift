enum RenderCmd : Int
{
  case END_RENDER
  case BEGIN_CANVAS                //( canvas_id:Int32X )
  case END_CANVAS
  case HEADER_CLEAR_COLOR          //( argb:Int32 )
  case HEADER_END
  case LOAD_TEXTURE                //( id:Int32X, filepath:String )
  case PUSH_OBJECT_TRANSFORM       //( transform:Real32[16], replace:Logical )
  case POP_OBJECT_TRANSFORM        //( count:Int32X )
  case PUSH_VIEW_TRANSFORM         //( transform:Real32[16], replace:Logical )
  case POP_VIEW_TRANSFORM          //( count:Int32X )
  case PUSH_PROJECTION_TRANSFORM   //( transform:Real32[16], replace:Logical )
  case POP_PROJECTION_TRANSFORM    //( count:Int32X )
  case DEFINE_RENDER_MODE          //( [id,shape]:Int32X, [src_blend,dest_blend]:BlendFactor, [vertex_shader,fragment_shader]:String )
  case USE_RENDER_MODE             //( id:Int32X )
  case PUSH_POSITIONS              //( count:Int32X, positions:XYZ32[count] )
  case PUSH_COLORS                 //( count:Int32X, colors:Int32[count] )
  case PUSH_UVS                    //( count:Int32X, positions:XY32[count] )
  case USE_TEXTURE                 //( id:Int32X )
}
