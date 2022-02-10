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
  // Uniforms are shader constants
    matrix_float4x4 projectionTransform;
    matrix_float4x4 worldTransform;
} Uniforms;

typedef NS_ENUM(NSInteger, TextureIndex)
{
  // TextureIndexColor, here, is used as TextureIndex.color in Swift
  TextureIndexColor = 0,  // Stage 0 of multi-stage textures is the texture color
};


//------------------------------------------------------------------------------
// TexturedVertex
// TransformedTexturedVertex
//------------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, TexturedBufferIndex)
{
    TexturedBufferIndexMeshPositions = 0,
    TexturedBufferIndexMeshGenerics  = 1,
    TexturedBufferIndexUniforms      = 2,
};

typedef NS_ENUM(NSInteger, TexturedVertexAttribute)
{
    TexturedVertexAttributePosition = 0,
    TexturedVertexAttributeTexcoord = 1,
};

//------------------------------------------------------------------------------
// ColoredVertex
// TransformedColoredVertex
//------------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, ColoredBufferIndex)
{
    ColoredBufferIndexMeshPositions = 0,
    ColoredBufferIndexMeshGenerics  = 1,
    ColoredBufferIndexMeshUVs       = 2,
    ColoredBufferIndexUniforms      = 3,
};

typedef NS_ENUM(NSInteger, ColoredVertexAttribute)
{
    ColoredVertexAttributePosition = 0,
    ColoredVertexAttributeColor    = 1,
    ColoredVertexAttributeUV       = 2,
};


#endif /* ShaderTypes_h */

