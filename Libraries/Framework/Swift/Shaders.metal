//
//  Shaders.metal
//  Project-macOS
//
//  Created by Abe Pralle on 1/28/22.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

//------------------------------------------------------------------------------
// Vertex
// TransformedVertex
//------------------------------------------------------------------------------
typedef struct
{
  float3 position [[attribute(VertexAttributePosition)]];
  float4 color    [[attribute(VertexAttributeColor)]];
  float2 uv       [[attribute(VertexAttributeUV)]];
} Vertex;

typedef struct
{
  float4 position [[position]];
  float4 color;
  float2 uv;
} TransformedVertex;

//------------------------------------------------------------------------------
// Solid Color Shaders
//------------------------------------------------------------------------------
vertex TransformedVertex solidColorVertexShader( Vertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]])
{
  TransformedVertex out;

  float4 position = float4( in.position, 1.0 );
  out.position = constants.projectionTransform * constants.worldTransform * position;
  out.color = in.color;

  return out;
}

fragment float4 solidColorFragmentShader(
    TransformedVertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]]
  )
{
    return in.color;
}

//------------------------------------------------------------------------------
// Texture Shaders
//------------------------------------------------------------------------------
vertex TransformedVertex textureVertexShader(Vertex in [[stage_in]],
                               constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]])
{
    TransformedVertex out;

    float4 position = float4(in.position, 1.0);
    out.position = constants.projectionTransform * constants.worldTransform * position;
    out.uv = in.uv;

    return out;
}

fragment float4 textureFragmentShader(
    TransformedVertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]],
    texture2d<half> colorMap     [[ texture(TextureStageColor) ]]
  )
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.uv.xy);

    return float4(colorSample);
}

