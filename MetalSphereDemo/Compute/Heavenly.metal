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
    float  intensity;  // HDR gain 1…10
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
    o = tanh(o / 2000.0) * uni.intensity;

    return o;
}

// ─────────────────────────────────────────────────────────────────────────────
// Compute kernel variant — renders directly into a 2-D texture so that the
// shader can be used as a low-level procedural texture generator (RealityKit
// ComputeSystem-compatible).
// ─────────────────────────────────────────────────────────────────────────────
kernel void heavenlyKernel(texture2d<float, access::write> outTex [[texture(0)]],
                           constant Uniforms&          uni      [[buffer(0)]],
                           uint2                       gid      [[thread_position_in_grid]]) {
    // Bounds check – skip threads that fall outside the target texture.
    uint width  = outTex.get_width();
    uint height = outTex.get_height();
    if (gid.x >= width || gid.y >= height) { return; }

    // Normalised UV in the range [-1, 1] with aspect-ratio correction.
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    uv *= float(height) / float(width);
    float3 r = float3(uv, 0.0);

    float4 o = float4(0.0);
    float  z = 0.0;

    // Outer ray-march loop (identical to fragment version).
    for (int i = 0; i < 100; i++) {
        // Wandering point.
        float3 FC = r;
        float3 p = z * normalize(FC * 2.0 - float3(r.x, r.y, r.y));
        p.z -= uni.time;

        // Fractal accumulation.
        for (float dIt = 1.0; dIt < 9.0; dIt /= 0.7) {
            p += cos(float3(p.y, p.z, p.x) * dIt + z * 0.2 - uni.time * 0.1) / dIt;
        }

        // Step.
        float dStep = 0.02 + 0.1 * abs(p.y + 1.0);
        z += dStep;

        // Accumulate colour.
        float4 phase = float4(0.0, 1.0, 2.0, 3.0);
        o += (cos(z + uni.time + phase) + 1.1) / dStep;
    }

    // Tone-mapping.
    o = tanh(o / 2000.0) * uni.intensity;

    outTex.write(o, gid);
}
