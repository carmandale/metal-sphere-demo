//
//  Uniforms.swift
//  MetalSphereDemo
//
//  Created by Dale Carman on 5/1/25.
//


#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────────────────────────────────
// Uniforms passed in via buffer(0):
// ─────────────────────────────────────────────────────────────────────────────
struct Uniforms {
    float2 resolution; // in pixels
    float  time;       // in seconds
};

// ─────────────────────────────────────────────────────────────────────────────
// Vertex / full-screen quad setup
// ─────────────────────────────────────────────────────────────────────────────
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    // A single triangle‐strip quad covering NDC [-1…1] × [-1…1]
    float2 quadCorners[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    VertexOut out;
    out.position = float4(quadCorners[vertexID], 0.0, 1.0);
    // UV in [0…1]
    out.uv = quadCorners[vertexID] * 0.5 + 0.5;
    return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fragment: “Heavenly 2” port of the XorDev ray-march loop
// ─────────────────────────────────────────────────────────────────────────────
fragment float4 fragment_main(VertexOut in            [[stage_in]],
                              constant Uniforms& uni   [[buffer(0)]]) {
    // normalize to [-1…1]
    float2 uv = in.uv * 2.0 - 1.0;
    // maintain aspect ratio
    uv *= uni.resolution.y / uni.resolution.x;
    float3 r = float3(uv, 0.0);

    float4 o = float4(0.0);
    float  z = 0.0;

    // Outer “ray‐march” iterations
    for (int i = 0; i < 100; i++) {
        // compute a wandering point “p”
        float3 FC = r; // treat FC.rgb → r
        float3 p = z * normalize(FC * 2.0 - float3(r.x, r.y, r.y));
        p.z -= uni.time;

        // inner fractal sum
        for (float d = 1.0; d < 9.0; d /= 0.7) {
            p += cos(float3(p.y, p.z, p.x) * d
                     + z * 0.2
                     - uni.time * 0.1)
                 / d;
        }

        // step size
        float d = 0.02 + 0.1 * abs(p.y + 1.0);
        z += d;

        // accumulate a 4‐channel color
        float4 phase = float4(0.0, 1.0, 2.0, 3.0);
        o += (cos(z + uni.time + phase) + 1.1) / d;
    }

    // final tonemapping
    o = tanh(o / 2000.0);

    return o;
}