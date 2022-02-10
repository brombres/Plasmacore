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
// TexturedVertex
// TransformedTexturedVertex
//------------------------------------------------------------------------------
//typedef struct
//{
//    float3 position [[attribute(TexturedVertexAttributePosition)]];
//    float2 texCoord [[attribute(TexturedVertexAttributeTexcoord)]];
//} TexturedVertex;
//
//typedef struct
//{
//    float4 position [[position]];
//    float2 texCoord;
//} TransformedTexturedVertex;


//------------------------------------------------------------------------------
// ColoredVertex
// TransformedColoredVertex
//------------------------------------------------------------------------------
typedef struct
{
    float3 position [[attribute(ColoredVertexAttributePosition)]];
    float4 color    [[attribute(ColoredVertexAttributeColor)]];
    float2 uv       [[attribute(ColoredVertexAttributeUV)]];
} ColoredVertex;

typedef struct
{
    float4 position [[position]];
    float4 color;
    float2 uv;
} TransformedColoredVertex;

vertex TransformedColoredVertex coloredVertexShader(ColoredVertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(ColoredBufferIndexUniforms) ]])
{
    TransformedColoredVertex out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionTransform * uniforms.worldTransform * position;
    out.color = in.color;

    return out;
}

fragment float4 coloredFragmentShader(
    TransformedColoredVertex in [[stage_in]],
    constant Uniforms & uniforms [[ buffer(ColoredBufferIndexUniforms) ]]
  )
{
    return in.color;
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
vertex TransformedColoredVertex texturedVertexShader(ColoredVertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(ColoredBufferIndexUniforms) ]])
{
    TransformedColoredVertex out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionTransform * uniforms.worldTransform * position;
    out.uv = in.uv;

    return out;
}

fragment float4 texturedFragmentShader(
    TransformedColoredVertex in [[stage_in]],
    constant Uniforms & uniforms [[ buffer(ColoredBufferIndexUniforms) ]],
    texture2d<half> colorMap     [[ texture(TextureIndexColor) ]]
  )
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.uv.xy);

    return float4(colorSample);
}
