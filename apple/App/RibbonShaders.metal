#include <metal_stdlib>
using namespace metal;

namespace {
constant float pi = 3.14159265358979323846;

float square(float x) { return x * x; }

// Exact IEC sRGB decoding for authored constants. All material math below is
// linear light. The completed opaque scene is encoded once at the output boundary.
float linearSRGB(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}
float3 linearSRGB(float3 c) {
    return float3(linearSRGB(c.x), linearSRGB(c.y), linearSRGB(c.z));
}

float encodedSRGB(float c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}
float3 encodedSRGB(float3 c) {
    return float3(encodedSRGB(c.x), encodedSRGB(c.y), encodedSRGB(c.z));
}

// Porter-Duff source-over for PREMULTIPLIED linear RGB and linear alpha.
// Alpha is independent of brightness; neither gamma nor max(RGB) belongs in it.
float4 over(float4 front, float4 back) {
    return front + back * (1 - front.a);
}

float3 displayMap(float3 radiance) {
    // One hue-preserving SDR shoulder after the entire scene is combined.
    // This is a display choice, separate from the physically linear light math.
    return radiance / (1 + max(radiance.x, max(radiance.y, radiance.z)));
}

float feather(float lower, float upper, float value) {
    float t = clamp((value - lower) / (upper - lower), 0.0, 1.0);
    return t * t * t * (t * (6 * t - 15) + 10);
}

struct RibbonPoint { float u; float distance; float2 normal; };
struct RibbonColors { float3 hues[6]; };

// Six additive color-wheel hues. Every hue retains a floor; the amount of
// each hue follows logarithmic band power. Secondary hues require both bands.
float3 spectrum(float angle, float3 power, thread const RibbonColors &palette) {
    float3 p = power / (power.x + power.y + power.z + 0.0001);
    // A regularized harmonic mean avoids a square-root derivative spike as
    // a previously silent band starts. All palette changes remain smooth.
    float weights[6] = {0.06 + p.x, 0.06 + 2 * p.x * p.y / (p.x + p.y + 0.0001),
                        0.06 + p.y, 0.06 + 2 * p.y * p.z / (p.y + p.z + 0.0001),
                        0.06 + p.z, 0.06 + 2 * p.z * p.x / (p.z + p.x + 0.0001)};
    float total = 0;
    for (int i = 0; i < 6; ++i) total += weights[i];
    float cursor = fract(angle / (2 * pi)) * total;
    for (int i = 0; i < 6; ++i) {
        if (cursor <= weights[i] || i == 5) {
            float x = clamp(cursor / weights[i], 0.0, 1.0);
            // Broad hue plateaus with C2 blends at both ends. Both sides of
            // every boundary agree in color, velocity and acceleration.
            if (x < 0.5)
                return mix(palette.hues[(i + 5) % 6], palette.hues[i], 0.5 + 0.5 * feather(0, 0.28, x));
            return mix(palette.hues[i], palette.hues[(i + 1) % 6], 0.5 * feather(0.72, 1, x));
        }
        cursor -= weights[i];
    }
    return palette.hues[0];
}

float2 curve(float t, float2 extent) {
    return extent * float2(sin(t), sin(2.0 * t));
}

// The two halves of a closed Gerono infinity are solved separately, preserving
// the over/under crossing. There is no discrete particle creation or respawning.
RibbonPoint nearest(float2 p, float2 extent, bool front) {
    float seed = asin(clamp(p.x / extent.x, -0.9999, 0.9999));
    float t = front ? seed : pi - seed;
    float lower = front ? -pi / 2 : pi / 2;
    float upper = front ? pi / 2 : 3 * pi / 2;
    for (int i = 0; i < 6; ++i) {
        float2 delta = curve(t, extent) - p;
        float2 tangent = extent * float2(cos(t), 2 * cos(2 * t));
        float2 curvature = extent * float2(-sin(t), -4 * sin(2 * t));
        float denominator = dot(tangent, tangent) + dot(delta, curvature);
        float step = dot(delta, tangent) / max(denominator, 40.0);
        t = clamp(t - clamp(step, -0.35, 0.35), lower, upper);
    }
    float2 tangent = normalize(extent * float2(cos(t), 2 * cos(2 * t)));
    float2 normal = float2(-tangent.y, tangent.x);
    float2 delta = p - curve(t, extent);
    float side = dot(delta, normal) < 0 ? -1.0 : 1.0;
    return {t, side * length(delta), normal};
}

struct Material { float3 body; float opacity; float3 atmosphere; float mistOpacity; };

// Shared by the infinity and all background loops: the same fluid, membrane,
// spectral streaks, shadows, mist, and edge lighting at every depth.
Material shade(RibbonPoint point, float phase, float active, float3 chosen,
               float3 power, bool front, float depthLayer, thread const RibbonColors &palette) {
    float u = point.u;
    // A broad current travels continuously; all modulation is spatially and
    // temporally smooth. Integer harmonics match exactly across phase wrap.
    float rate = depthLayer == 0 ? 12 : (depthLayer == 1 ? 8 : (depthLayer == 2 ? 5 : (depthLayer == 3 ? 4 : 3)));
    float flow = u - rate * phase;
    float radius = 5.0 + 0.65 * sin(3 * u - 4 * phase) + 0.35 * sin(5 * u + 3 * phase);
    if (abs(point.distance) > radius + 19) return {float3(0), 0, float3(0), 0};
    float v = point.distance / radius;
    float coverage = 1 - feather(radius - 0.55, radius + 0.55, abs(point.distance));
    float roundness = exp(-1.4 * v * v);
    float edgeLight = pow(max(0.0, roundness * 0.83 - v * point.normal.y * 0.44), 6.0);

    float bend = 0.40 * sin(3 * flow + 0.55 * sin(2 * u + 5 * phase));
    float filamentA = exp(-square((v - bend) * 4.6));
    float filamentB = exp(-square((v + 0.38 * sin(2 * flow + 0.8) + 0.12) * 8.0));
    float membrane = 0.5 + 0.5 * sin(4 * flow + 2.5 * v + 0.7 * sin(3 * u - 7 * phase));
    float current = square(square(0.5 + 0.5 * cos(flow)));

    float3 tint = mix(float3(linearSRGB(0.24)), mix(chosen, float3(linearSRGB(0.72)), 0.10), active);
    float3 spectralA = spectrum(flow + 0.45 * v, power, palette);
    float3 spectralB = spectrum(flow + pi + 0.30 * sin(2 * u), power, palette);
    // C2-continuous depth at the tips, strongest on the back crossing.
    float rear = front ? 0.0 : feather(0.0, 0.85, -cos(u));
    float depth = 1.0 - 0.58 * rear;
    float surfaceOpacity = coverage * (0.90 - 0.28 * rear);
    float3 body = tint * (0.26 + 0.32 * roundness + active * (0.16 * membrane + 0.40 * current));
    body += active * (mix(tint, spectralA, 0.78) * 0.60 * filamentA
                     + mix(tint, spectralB, 0.82) * 0.32 * filamentB) * (0.40 + 0.60 * current);
    body += active * spectralB * 0.14 * roundness * (1 - membrane);
    body += mix(float3(linearSRGB(0.05)), float3(linearSRGB(0.18)), active) * edgeLight;
    body += active * linearSRGB(float3(0.13, 0.14, 0.15)) * filamentA * current;
    body *= depth;
    // The narrow cores transmit their own hue rather than adding RGB light to
    // the body (which washed greens/cyans into the dominant pink/red). Most of
    // the ribbon still retains the fully mixed color around these fine strands.
    float filaments = filamentA + filamentB;
    float3 prism = (spectralA * filamentA + spectralB * filamentB) / max(filaments, 0.00001);
    float transmission = active * (1 - exp(-3.8 * filaments));
    body = mix(body, prism * (0.32 + 0.36 * roundness + 0.20 * current) * depth, transmission);

    // Vapor stays close to the ribbon, with feathered edges rather than a hard
    // mask. Its density flows along the same closed path as the internal fluid.
    float outside = abs(point.distance) - radius;
    float outer = 0.5 * (outside + sqrt(outside * outside + 0.35));
    float mistOffset = 2.1 + 1.1 * sin(3 * flow + 2 * v);
    float vapor = exp(-square((outer - mistOffset) / 3.2));
    float edgeFade = feather(radius - 1.0, radius + 1.4, abs(point.distance));
    float density = 0.45 + 0.55 * square(0.5 + 0.5 * sin(3 * flow + 1.2 * sin(u + 3 * phase)));
    float glow = exp(-outer * outer / 14.0);
    // Beer-Lambert transmittance: optical densities add; opacity does not.
    float opticalDepth = active * edgeFade * (0.24 * vapor * density + 0.06 * glow);
    float mistOpacity = 1 - exp(-opticalDepth);
    float3 atmosphere = mix(tint, spectralA, 0.28) * depth * mistOpacity;
    return {body, surfaceOpacity, atmosphere, mistOpacity};
}

struct CurveSample { float2 point; float2 tangent; float2 curvature; };

CurveSample loopCurve(float u, float2 extent, float phase, float depth) {
    float a = 0.12 * sin(max(1.0, 4 - depth) * phase + depth);
    float b = 0.10 * cos(max(1.0, 3 - depth) * phase + 2 * depth);
    float second = 2 * u + 0.5 * depth;
    float third = 3 * u - depth;
    return {extent * float2(sin(u) + a * sin(second), cos(u) + b * cos(third)),
            extent * float2(cos(u) + 2 * a * cos(second), -sin(u) - 3 * b * sin(third)),
            extent * float2(-sin(u) - 4 * a * sin(second), -cos(u) - 9 * b * cos(third))};
}

RibbonPoint nearestLoop(float2 p, float2 extent, float phase, float depth) {
    float u = atan2(p.x / extent.x, p.y / extent.y);
    for (int i = 0; i < 6; ++i) {
        CurveSample c = loopCurve(u, extent, phase, depth);
        float2 delta = c.point - p;
        float denominator = dot(c.tangent, c.tangent) + dot(delta, c.curvature);
        u -= clamp(dot(delta, c.tangent) / max(denominator, 40.0), -0.35, 0.35);
    }
    CurveSample c = loopCurve(u, extent, phase, depth);
    float2 tangent = normalize(c.tangent);
    float2 normal = float2(-tangent.y, tangent.x);
    float2 delta = p - c.point;
    return {u, (dot(delta, normal) < 0 ? -1.0 : 1.0) * length(delta), normal};
}

float4 materialLayer(Material m) {
    return over(float4(m.body * m.opacity, m.opacity), float4(m.atmosphere, m.mistOpacity));
}

float4 renderLoop(float2 p, float2 extent, float phase, float active,
                  float3 chosen, float3 power, float depth, thread const RibbonColors &palette) {
    RibbonPoint point = nearestLoop(p, extent, phase * 2, depth);
    Material m = shade(point, phase, active, chosen, power, true, depth, palette);
    return materialLayer(m);
}

// Four closed loops in a stable viewport. Inverse mapping keeps transforms
// continuous in floating point BEFORE rasterization, rather than moving and
// rotating four magnified offscreen images through SwiftUI layout each frame.
float4 backdrop(float2 position, float2 canvas, float phase, float active,
                float3 chosen, float3 power, thread const RibbonColors &palette) {
    const float scales[4] = {5.6, 4.6, 3.6, 2.8};
    const float opacity[4] = {0.028, 0.044, 0.064, 0.090};
    const float2 centers[4] = {float2(0.12, -0.06), float2(0.82, 0.29), float2(-0.12, 0.64), float2(0.88, 1.0)};
    const float tilt[4] = {-0.20, 0.24, -0.32, 0.38};
    const float orbit[4] = {0.4, 2.1, 3.8, 5.3};
    float reference = min(canvas.x, 900.0);
    float4 result = 0;
    for (int i = 0; i < 4; ++i) {
        float depth = 4 - i, rate = i < 2 ? 2 : 3;
        float progress = phase * rate + orbit[i];
        float angle = tilt[i] + 0.12 * sin(progress + 0.7);
        float2 drift = float2(0.10 * sin(progress) + 0.025 * sin(phase + orbit[i]),
                              0.065 * cos(progress) + 0.02 * sin(2 * phase + orbit[i]));
        float2 center = canvas * (centers[i] + drift);
        // Slow changes in depth and tilt suggest floating in space. Every
        // transform is continuous and evaluated before rasterization; integer
        // phase harmonics also join smoothly across the four-minute wrap.
        float depthScale = 1 + 0.045 * sin(progress + 1.2);
        float2 p = (position - center) * (200.0 / (reference * scales[i] * depthScale));
        float c = cos(angle), s = sin(angle);
        p = float2(c * p.x + s * p.y, -s * p.x + c * p.y);
        p.y /= 0.90 + 0.08 * cos(progress + 0.4);
        // Conservative bound includes the maximum curve deformation and mist.
        if (abs(p.x) > 106 || abs(p.y) > 70) continue;
        float distanceFade = 0.93 + 0.07 * cos(progress + 0.8);
        float4 layer = renderLoop(p, float2(72, 39.68), phase, active, chosen, power, depth, palette) * opacity[i] * distanceFade;
        result = over(layer, result);
    }
    return result;
}

float4 renderInfinity(float2 p, float phase, float active, float3 chosen,
                      float3 power, thread const RibbonColors &palette) {
    float2 extent = float2(61.6, 25.65);
    RibbonPoint nearFront = nearest(p, extent, true);
    RibbonPoint nearBack = nearest(p, extent, false);
    Material back = shade(nearBack, phase, active, chosen, power, false, 0, palette);
    Material front = shade(nearFront, phase, active, chosen, power, true, 0, palette);
    float4 frontLayer = materialLayer(front), backLayer = materialLayer(back);
    float4 crossed = over(frontLayer, backLayer);
    // Only merge samples that converge on the SAME shared tip. Separate
    // portions of the curve keep their independently composited atmosphere.
    // Choosing a nearest half with a boolean produced a visible mist seam on
    // the equidistant centerline; both this blend and its gate are C2 smooth.
    float phaseGap = abs(atan2(sin(nearFront.u - nearBack.u), cos(nearFront.u - nearBack.u)));
    float sharedTip = 1 - feather(0.08, 0.36, phaseGap);
    float frontShare = 1 - feather(-0.75, 0.75, abs(nearFront.distance) - abs(nearBack.distance));
    float4 continuousTip = mix(backLayer, frontLayer, frontShare);
    return mix(crossed, continuousTip, sharedTip);
}
}

[[ stitchable ]] half4 livingRibbon(float2 position, half4 source, float2 size,
                                    float phase, float active, float3 chosen,
                                    float3 power, float shape, float depthLayer, float2 canvas,
                                    float3 hue0, float3 hue1, float3 hue2,
                                    float3 hue3, float3 hue4, float3 hue5,
                                    float4 infinityRect, float ambience) {
    RibbonColors palette = {{hue0, hue1, hue2, hue3, hue4, hue5}};
    float2 canvasPosition = position * canvas / size;
    if (shape > 2.5) {
        // Compose ALL artwork here, in one linear-light scene. Separate
        // SwiftUI foreground/background textures would blend again outside
        // their drawing groups and could reintroduce gamma-space overlaps.
        float4 result = ambience > 0 ? backdrop(canvasPosition, canvas, phase, active, chosen, power, palette) * ambience : float4(0);
        if (infinityRect.z > 0 && infinityRect.w > 0) {
            float2 p = canvasPosition - infinityRect.xy - infinityRect.zw * 0.5;
            p /= max(0.001, min(infinityRect.z / 160, infinityRect.w / 90));
            if (abs(p.x) < 90 && abs(p.y) < 50) {
                result = over(renderInfinity(p, phase, active, chosen, power, palette), result);
            }
        }
        // Opaque black is the final backdrop. Encode only after every overlap
        // and the display map. No translucent encoded RGB leaves this shader,
        // so SwiftUI cannot re-composite our ribbons in gamma space.
        return half4(half3(encodedSRGB(displayMap(result.rgb))), 1) * source.a;
    }
    // Raw premultiplied linear surfaces are also exposed to the GPU audit.
    if (shape > 1.5)
        return half4(backdrop(canvasPosition, canvas, phase, active, chosen, power, palette)) * source.a;
    float2 p = position - size * 0.5;
    if (shape > 0.5)
        return half4(renderLoop(p, size * float2(0.36, 0.31), phase, active, chosen, power, depthLayer, palette)) * source.a;
    p /= max(0.001, min(size.x / 160.0, size.y / 90.0));
    return half4(renderInfinity(p, phase, active, chosen, power, palette)) * source.a;
}
