#include <metal_stdlib>
using namespace metal;

// Parameters passed from Swift each frame
struct Params {
    float time;
    float intensity; // HDR gain 1..10
};

// Pi constant (Metal doesn't guarantee M_PI)
constant float PI = 3.14159265358979323846;

// Helper: spherical direction from UV on equirect texture
static inline float3 directionFromUV(float2 uv) {
    float phi = uv.y * PI;          // 0..pi
    float theta = uv.x * 2.0f * PI; // 0..2pi
    float3 dir;
    dir.x = sin(phi) * sin(theta);
    dir.y = cos(phi);
    dir.z = sin(phi) * cos(theta);
    return dir;
}

// === Effect Sphere =========================================================
static float4 effectSphereColor(float3 dir, float time) {
    float3 r = float3(1.0,1.0,1.0);
    float3 FC = dir;
    float4 o = float4(0.0);
    float z = 0.0;
    float d = 1.0;
    const int ITER = 100;
    for(int i=0;i<ITER;++i){
        float3 p = z*normalize(FC*2.0 - r.xyy);
        p.z -= time;
        d = 1.0;
        for(float k=1.0;k<9.0;k/=0.7){
            p += cos(p.yzx*k + z*0.2 - time*0.1)/k;
            d = k;
        }
        z += d = 0.02 + 0.1*abs(p.y+1.0);
        o += (cos(z+time+float4(0.0,1.0,2.0,3.0))+1.1)/d;
    }
    return tanh(o/2000.0);
}

kernel void effectSphereKernel(texture2d<float, access::write> outTex [[texture(0)]],
                               constant Params& params [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(outTex.get_width(), outTex.get_height());
    if(gid.x >= size.x || gid.y >= size.y) return;
    float2 uv = (float2(gid) + 0.5)/float2(size);
    float3 dir = directionFromUV(uv);
    float4 col = effectSphereColor(dir, params.time) * params.intensity;
    outTex.write(col, gid);
}

// === Tunnel ================================================================
static inline float2 rot2d(float2 v,float a){float ca=cos(a);float sa=sin(a);return float2(ca*v.x-sa*v.y, sa*v.x+ca*v.y);} 

static float4 tunnelColor(float3 dir, float time){
    float2 r=float2(1.0,1.0);
    float3 FC=dir;
    float4 o=float4(0.0);
    float z=0.0;
    float d=1.0;
    const int ITER=50;
    for(int i=0;i<ITER;++i){
        float3 p=z*normalize(FC*2.0 - float3(r.x,r.y,0.0));
        p.z-=time;
        float2 rot = rot2d(p.xy, p.z*0.5);
        p.x=rot.x; p.y=rot.y;
        d=2.0;
        for(float k=2.0;k<15.0;k/=0.4){
            p += cos((p.yzx-time)*k)/k;
            d=k;
        }
        z += d = 0.02 + fabs(length(p.xy)-4.0)/8.0;
        o += float4(1.0,2.0,3.0,1.0)/d;
    }
    return tanh(o/2000.0);
}

kernel void tunnelKernel(texture2d<float, access::write> outTex [[texture(0)]],
                         constant Params& params [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(outTex.get_width(), outTex.get_height());
    if(gid.x >= size.x || gid.y >= size.y) return;
    float2 uv = (float2(gid) + 0.5)/float2(size);
    float3 dir = directionFromUV(uv);
    float4 col = tunnelColor(dir, params.time) * params.intensity;
    outTex.write(col, gid);
} 