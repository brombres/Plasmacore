class Matrix
{
  class func identity()->matrix_float4x4
  {
    let c4 = vector_float4( 0, 0, 0, 1 )
    let c3 = vector_float4( 0, 0, 1, 0 )
    let c2 = vector_float4( 0, 1, 0, 0 )
    let c1 = vector_float4( 1, 0, 0, 0 )
    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }

  class func perspective( _ fovY_radians:Float, _ aspectRatio:Float, _ zNear:Float, _ zFar:Float )->matrix_float4x4
  {
    // Returns a right-handed projection matrix
    let ys = 1.0 / tanf(fovY_radians * 0.5)
    let xs = ys / aspectRatio
    let zs = zFar / (zNear - zFar)
    let zn = zs * zNear

    let c4 = vector_float4(  0,  0, zn,  0 )
    let c3 = vector_float4(  0,  0, zs, -1 )
    let c2 = vector_float4(  0, ys,  0,  0 )
    let c1 = vector_float4( xs,  0,  0,  0 )
    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }

  class func rotate( _ theta:Float, _ axisX:Float, _ axisY:Float, _ axisZ:Float )->matrix_float4x4
  {
    var x = axisX
    var y = axisY
    var z = axisZ

    // Normalize the axis vector
    let sumOfSquares = x*x + y*y + z*z
    if (sumOfSquares < 0.9999 || sumOfSquares > 1.0001)
    {
      let m = sqrtf( sumOfSquares )
      x /= m
      y /= m
      z /= m
    }

    let ct = cosf(theta)
    let st = sinf(theta)
    let ci = 1.0 - ct

    let c4 = vector_float4(                   0,                   0,                   0, 1 )
    let c3 = vector_float4( x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0 )
    let c2 = vector_float4( x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0 )
    let c1 = vector_float4(     ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0 )

    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }

  class func translate( _ x:Float, _ y:Float, _ z:Float )->matrix_float4x4
  {
    let c4 = vector_float4( x, y, z, 1 )
    let c3 = vector_float4( 0, 0, 1, 0 )
    let c2 = vector_float4( 0, 1, 0, 0 )
    let c1 = vector_float4( 1, 0, 0, 0 )
    return matrix_float4x4.init( columns:(c1,c2,c3,c4) )
  }
}

