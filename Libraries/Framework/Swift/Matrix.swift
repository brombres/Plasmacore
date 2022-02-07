class Matrix
{
  class func identity()->matrix_float4x4
  {
    let c1 = vector_float4( 1, 0, 0, 0 )
    let c2 = vector_float4( 0, 1, 0, 0 )
    let c3 = vector_float4( 0, 0, 1, 0 )
    let c4 = vector_float4( 0, 0, 0, 1 )
    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }
}

