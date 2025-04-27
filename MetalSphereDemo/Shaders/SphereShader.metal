//
//  VertexOut.swift
//  Metal
//
//  Created by Dale Carman on 4/26/25.
//


//  SphereShader.metal
#include <metal_stdlib>
using namespace metal;

// ────────────────  Shared structs ──────────────────────────────────
struct VertexOut {
    float4 position [[position]];
    float2 uv       [[user(texturecoords)]];
};

struct SphereUniforms { float time; };

// Simple HSV→RGB helper (same one Shadertoy uses)
static float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ────────────────  Fragment shader ─────────────────────────────────
fragment float4 sphereEffectFragment(
    VertexOut                in                 [[stage_in]],
    constant SphereUniforms& u                  [[buffer(0)]])
{
    // Film-coord 0–1
    float2 FC = in.uv;
    float r   = 1.0;

    float3 colorAccum = float3(0.0);
    float   g = 0.0, e = 0.0, s = 0.0;

    // Port of your single-line GLSL (slightly spaced out for sanity)
    for (int I = 0; I < 99; ++I) {

        float3 p = float3( (FC - 0.5 * r) / r * 1.6 + float2(0.0, 1.0),
                           g - 7.0 );

        // ─ Rotate around XZ in time ─
        float cs = cos(u.time * 0.3);
        float sn = sin(u.time * 0.3);
        p.xz = float2( p.x * cs - p.z * sn,
                       p.x * sn + p.z * cs );

        s = 6.0;
        for (int J = 0; J < 12; ++J) {
            p = float3(1.0, 4.1, -1.0) - abs( abs(p) * e - float3(3.0, 4.0, 3.0) );
            s = e = 7.0 / dot( p, p * 0.47 );
        }

        g += p.y / s * 1.4;
        s  = log2(s) - g;

        float h = s / (g * p.y + 1e-3);  // avoid /0
        float v = s / 150.0;

        colorAccum += hsv2rgb(float3(h, 0.7, v));
    }

    return float4(colorAccum / 99.0, 1.0);
}