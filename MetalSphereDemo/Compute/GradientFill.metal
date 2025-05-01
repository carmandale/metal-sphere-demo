//
//  GradientFill.metal
//  MetalSphereDemo
//
//  Simple compute shader that fills a texture with an easy-to-see
//  UV-based gradient. Use this to verify that the compute pipeline,
//  texture writes, and material sampling all work end-to-end.
//

#include <metal_stdlib>
using namespace metal;

// Keep the uniform struct identical to FractalUniforms so that
// FractalSystem can keep using its existing uniform buffer.
struct FractalUniforms { float time; };

// ----------------------------------------------------------------------
//  Kernel: gradientFill2D
// ----------------------------------------------------------------------
kernel void gradientFill2D(texture2d<float, access::write> outTex [[texture(0)]],
                           constant FractalUniforms&         uni   [[buffer(0)]],
                           uint2                             gid   [[thread_position_in_grid]])
{
    uint2 dim = uint2(outTex.get_width(), outTex.get_height());
    if (any(gid >= dim)) return;

    // Normalised UV (0–1)
    float2 uv = (float2(gid) + 0.5) / float2(dim);

    // Smooth sine-based stripes: continuous motion without abrupt jumps.
    float phase  = uv.x * 10.0 + uni.time * 0.5;        // slide pattern over time
    float stripe = 0.5 + 0.5 * sin(phase * 6.2831853);  // 0‒1 via sine wave (2π)
    outTex.write(float4(stripe, uv.y, 1.0 - stripe, 1.0), gid);
}
