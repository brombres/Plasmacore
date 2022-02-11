//
//  ShaderTypes.h
//  Project-macOS
//
//  Created by Abe Pralle on 1/28/22.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

//------------------------------------------------------------------------------
// General
//------------------------------------------------------------------------------
typedef struct
{
    matrix_float4x4 projectionTransform;
    matrix_float4x4 worldTransform;
} Constants;

typedef NS_ENUM( NSInteger, TextureStage )
{
  TextureStageColor = 0,
};

//------------------------------------------------------------------------------
// Vertex
// TransformedVertex
//------------------------------------------------------------------------------
typedef NS_ENUM( NSInteger, VertexBufferIndex )
{
    VertexBufferIndexPositions = 0,
    VertexBufferIndexColors    = 1,
    VertexBufferIndexUVs   = 2,
    VertexBufferIndexConstants = 3,
};

typedef NS_ENUM( NSInteger, VertexAttribute )
{
    VertexAttributePosition = 0,
    VertexAttributeColor    = 1,
    VertexAttributeUV       = 2,
};


#endif /* ShaderTypes_h */

