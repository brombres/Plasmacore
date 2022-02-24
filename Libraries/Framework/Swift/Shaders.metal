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
vertex TransformedVertex solidFillVertexShader( Vertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]] )
{
  TransformedVertex out;

  float4 position = float4( in.position, 1.0 );
  out.position = constants.projectionTransform * constants.worldTransform * position;
  out.color = in.color;

  return out;
}

fragment float4 solidFillFragmentShader(
    TransformedVertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]],
    sampler samplr [[sampler(0)]]
  )
{
    return in.color;
}

//------------------------------------------------------------------------------
// Texture Shaders
//------------------------------------------------------------------------------
vertex TransformedVertex alphaTextureVertexShader(Vertex in [[stage_in]],
                               constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]])
{
    TransformedVertex out;

    float4 position = float4(in.position, 1.0);
    out.position = constants.projectionTransform * constants.worldTransform * position;
    out.uv = in.uv;

    return out;
}

fragment float4 alphaTextureFragmentShader(
    TransformedVertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]],
    texture2d<half> colorMap     [[ texture(TextureStageColor) ]],
    sampler samplr [[sampler(0)]]
  )
{
    half4 colorSample   = colorMap.sample(samplr, in.uv.xy);

    return float4(colorSample);
}

//------------------------------------------------------------------------------
// Color Multiplied Textured Shaders
//------------------------------------------------------------------------------
vertex TransformedVertex alphaTextureMultiplyVertexShader(Vertex in [[stage_in]],
                               constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]])
{
    TransformedVertex out;

    float4 position = float4(in.position, 1.0);
    out.position = constants.projectionTransform * constants.worldTransform * position;
    out.uv = in.uv;
    out.color = in.color;

    return out;
}

fragment float4 alphaTextureMultiplyFragmentShader(
    TransformedVertex in [[stage_in]],
    constant Constants & constants [[ buffer(VertexBufferIndexConstants) ]],
    texture2d<half> colorMap     [[ texture(TextureStageColor) ]],
    sampler samplr [[sampler(0)]]
  )
{
    half4 colorSample   = colorMap.sample(samplr, in.uv.xy);

    return float4(colorSample) * in.color;
}

