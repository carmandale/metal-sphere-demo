//
//  FractalUniforms.swift
//  MetalSphereDemo
//
//  Created by Dale Carman on 4/26/25.
//


#include <metal_stdlib>
using namespace metal;

/* Built-in helper functions from Apple’s sample — keep the #include path
   exactly as in ComputeUtilities.swift */
#include "Helpers.h"

struct FractalUniforms { float time; };

kernel void sphereFractal2D(texture2d<float, access::write> outTex [[texture(0)]],
                            constant FractalUniforms&         uni  [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]])
{
    uint2 dim = uint2(outTex.get_width(), outTex.get_height());
    if (any(gid >= dim)) return;

    /* Normalised UV (0–1) */
    float2 uv = (float2(gid) + 0.5) / float2(dim);

    /* === Your GLSL logic, slightly expanded for clarity === */
    float3 col = 0;
    float  g=0,e=0,s=0,r=1.0;

    for (int I=0; I<99; ++I) {
        float3 p = float3((uv - 0.5*r)/r*1.6 + float2(0,1), g-7);

        float cs = cos(uni.time*0.3);
        float sn = sin(uni.time*0.3);
        p.xz = float2(p.x*cs - p.z*sn,
                      p.x*sn + p.z*cs);

        s = 6;
        for (int J=0; J<12; ++J) {
            p = float3(1,4.1,-1) - abs(abs(p)*e - float3(3,4,3));
            s = e = 7 / dot(p, p*0.47);
        }

        g += p.y / s * 1.4;
        s  = log2(s) - g;

        float h = s / (g*p.y + 1e-3);
        float v = s / 150.0;

        /* HSV→RGB */
        float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
        float3 p2 = abs(fract(float3(h)+K.xyz)*6.0 - K.www);
        float3 rgb = v * mix(K.xxx, clamp(p2-K.xxx,0.0,1.0), 0.7);

        col += rgb;
    }
    col /= 99.0;

    outTex.write(float4(col,1.0), gid);
}