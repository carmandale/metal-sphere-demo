//
//  FancyFractal.metal
//  MetalSphereDemo  •  visionOS 2.5
//
//  Produces a bright HDR fractal for an additive “plasma” sphere.
//  Key goals tackled in this version:
//
//  •   HDR output ........................ lets colours exceed 1.0 for real glow
//  •   Blue-noise dithering .............. hides banding on mid-tones
//  •   Direction jitter .................. breaks the equatorial hot-spot ring
//  •   Runtime control ................... uniform-driven intensity + jitter
//
//  The file is organised as:
//
//      0)  #includes + helper hash
//      1)  Uniform struct   (matches Swift side)
//      2)  Helper math      (HSV→RGB, 2-D rotation, blue-noise hash)
//      3)  Kernel           (fancyFractal2D)
//
//  ---------------------------------------------------------------------------
//  0)  #includes + hash helper
//  ---------------------------------------------------------------------------

#include <metal_stdlib>
using namespace metal;

// Tiny blue-noise hash:  float2 → 0‥1  (credit: IQ / Inigo Quilez)
static inline float hash21(float2 p)
{
    return fract(sin(dot(p, float2(127.1,311.7))) * 43758.5453);
}

//  ---------------------------------------------------------------------------
//  1)  Uniforms  (must match Swift’s FractalUniforms struct exactly)
//  ---------------------------------------------------------------------------
struct FractalUniforms
{
    float time;        // seconds since start  ➜ drives slow rotation
    float intensity;   // HDR gain             ➜ 1‥10 is typical
    float jitter;      // 0‥1 : amount of direction jitter
    float density;     // NEW 0‥1   0 = many tiny dots, 1 = few large dots
    float amount;     // NEW 1‥5  integer-ish multiplier for “how many dots”
};

//  ---------------------------------------------------------------------------
//  2)  Small helpers
//  ---------------------------------------------------------------------------

// 2-line HSV ➜ RGB (from Shadertoy reference)
static inline float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simple 2-D rotation
static inline float2 rot2D(float2 v, float a)
{
    float s = sin(a), c = cos(a);
    return float2(c*v.x - s*v.y, s*v.x + c*v.y);
}

//  ---------------------------------------------------------------------------
//  3)  Kernel  –  writes one RGBA16F texel per invocation
//  ---------------------------------------------------------------------------
kernel void fancyFractal2D(texture2d<float, access::write> outTex [[texture(0)]],
                           constant FractalUniforms&         uni   [[buffer(0)]],
                           uint2                             gid   [[thread_position_in_grid]])
{
    //---------------------------------------------------------------------
    // Bounds check (always first – saves GPU work on partial threadgroups)
    //---------------------------------------------------------------------
    uint2 dim = uint2(outTex.get_width(), outTex.get_height());
    if (any(gid >= dim)) return;

    //---------------------------------------------------------------------
    // 3.1  UV → 3-D ray direction with jitter
    //---------------------------------------------------------------------
    float2 uv = (float2(gid) + 0.5) / float2(dim);
    uv.y = 1.0 - uv.y;                       // flip so north pole is up

    // Blue-noise per-pixel values (two independent channels)
    float n1 = hash21(float2(gid));
    float n2 = hash21(float2(gid) + 37.0);

    // Jitter scale:   uni.jitter ∈ [0,1],   0.01 rad ≈ 0.6°
    float jitter = uni.jitter * 0.01;

    // Spherical angles with jitter
    float theta = (uv.x + (n1 - 0.5) * jitter) * M_PI_F * 2.0; // longitude
    float phi   = (uv.y + (n2 - 0.5) * jitter) * M_PI_F;       // latitude

    // Convert to unit direction vector
    float3 dir = float3(sin(phi)*cos(theta),
                        cos(phi),
                        sin(phi)*sin(theta));

    //---------------------------------------------------------------------
    // 3.2  Fractal loop (identical maths, but untouched)
    //---------------------------------------------------------------------
    float3 colorAccum = float3(0.0);
    float  g          = 0.0;

    for (int I = 0; I < 99; ++I)
    {
        float3 p = dir * 1.6 + float3(0.0, 1.0, g - 7.0);
        p.xz = rot2D(p.xz, uni.time * 0.05);

        float s = 6.0, e = 1.0;
        for (int J = 0; J < 12; ++J) {
            p = float3(1.0, 4.1, -1.0) - abs(abs(p) * e - float3(3.0,4.0,3.0));
            e = 7.0 / max(dot(p, p * 0.47), 1e-4);
            s *= e;
        }

        g += p.y / s * 1.4;
        s  = log2(max(s, 1e-4)) - g;

        float h = s / (g * p.y + 1e-4);            // hue
        float v = clamp(pow(s / 100.0, 1.2), 0.0, 1.0); // value

        colorAccum += hsv2rgb(float3(h, 0.7, v));
    }

    // ─── 3.3  Post-processing  (HDR gain + dither + alpha) ───────────────────
    // ----- post --------------------------------------------------------
    float3 col = max(colorAccum/6.0, 0.0);

    // density (same behaviour you liked)
    float cutoff = mix(0.1, 0.8, uni.density);
    // density threshold
    float3 mask = smoothstep(cutoff, cutoff + 0.02, col);
    col = col * mask * uni.intensity;

    col += (n1 - 0.5) / 256.0;
    col = max(col, 0.05);

    outTex.write(float4(col, 1.0), gid);
}
