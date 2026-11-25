#version 300 es
precision highp float;
uniform vec2 canvas;
uniform vec4 infinityRect;
uniform float phase;
uniform float activity;
uniform float ambience;
uniform vec3 chosen;
uniform vec3 power;
uniform vec3 hues[6];
out vec4 fragColor;
const float pi = 3.14159265358979323846;

float square(float x) { return x * x; }

// Exact IEC sRGB decoding for authored constants. All material math below is
// linear light. The completed opaque scene is encoded once at the output boundary.
float linearSRGB(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}
vec3 linearSRGB(vec3 c) {
    return vec3(linearSRGB(c.x), linearSRGB(c.y), linearSRGB(c.z));
}

float encodedSRGB(float c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}
vec3 encodedSRGB(vec3 c) {
    return vec3(encodedSRGB(c.x), encodedSRGB(c.y), encodedSRGB(c.z));
}

// Porter-Duff source-over for PREMULTIPLIED linear RGB and linear alpha.
// Alpha is independent of brightness; neither gamma nor max(RGB) belongs in it.
vec4 over(vec4 front, vec4 back) {
    return front + back * (1.0 - front.a);
}

vec3 displayMap(vec3 radiance) {
    // One hue-preserving SDR shoulder after the entire scene is combined.
    // This is a display choice, separate from the physically linear light math.
    return radiance / (1.0 + max(radiance.x, max(radiance.y, radiance.z)));
}

float feather(float lower, float upper, float value) {
    float t = clamp((value - lower) / (upper - lower), 0.0, 1.0);
    return t * t * t * (t * (6.0 * t - 15.0) + 10.0);
}

struct RibbonPoint { float u; float distance; vec2 normal; };
struct RibbonColors { vec3 hues[6]; };

// Six additive color-wheel hues. Every hue retains a floor; the amount of
// each hue follows logarithmic band power. Secondary hues require both bands.
vec3 spectrum(float angle, vec3 power, RibbonColors palette) {
    vec3 p = power / (power.x + power.y + power.z + 0.0001);
    // A regularized harmonic mean avoids a square-root derivative spike as
    // a previously silent band starts. All palette changes remain smooth.
    float weights[6] = float[6](0.06 + p.x, 0.06 + 2.0 * p.x * p.y / (p.x + p.y + 0.0001),
                        0.06 + p.y, 0.06 + 2.0 * p.y * p.z / (p.y + p.z + 0.0001),
                        0.06 + p.z, 0.06 + 2.0 * p.z * p.x / (p.z + p.x + 0.0001));
    float total = 0.0;
    for (int i = 0; i < 6; ++i) total += weights[i];
    float cursor = fract(angle / (2.0 * pi)) * total;
    for (int i = 0; i < 6; ++i) {
        if (cursor <= weights[i] || i == 5) {
            float x = clamp(cursor / weights[i], 0.0, 1.0);
            // Broad hue plateaus with C2 blends at both ends. Both sides of
            // every boundary agree in color, velocity and acceleration.
            if (x < 0.5)
                return mix(palette.hues[(i + 5) % 6], palette.hues[i], 0.5 + 0.5 * feather(0.0, 0.28, x));
            return mix(palette.hues[i], palette.hues[(i + 1) % 6], 0.5 * feather(0.72, 1.0, x));
        }
        cursor -= weights[i];
    }
    return palette.hues[0];
}

vec2 curve(float t, vec2 extent) {
    return extent * vec2(sin(t), sin(2.0 * t));
}

// The two halves of a closed Gerono infinity are solved separately, preserving
// the over/under crossing. There is no discrete particle creation or respawning.
RibbonPoint nearest(vec2 p, vec2 extent, bool front) {
    float seed = asin(clamp(p.x / extent.x, -0.9999, 0.9999));
    float t = front ? seed : pi - seed;
    float lower = front ? -pi / 2.0 : pi / 2.0;
    float upper = front ? pi / 2.0 : 3.0 * pi / 2.0;
    for (int i = 0; i < 6; ++i) {
        vec2 delta = curve(t, extent) - p;
        vec2 tangent = extent * vec2(cos(t), 2.0 * cos(2.0 * t));
        vec2 curvature = extent * vec2(-sin(t), -4.0 * sin(2.0 * t));
        float denominator = dot(tangent, tangent) + dot(delta, curvature);
        float step = dot(delta, tangent) / max(denominator, 40.0);
        t = clamp(t - clamp(step, -0.35, 0.35), lower, upper);
    }
    vec2 tangent = normalize(extent * vec2(cos(t), 2.0 * cos(2.0 * t)));
    vec2 normal = vec2(-tangent.y, tangent.x);
    vec2 delta = p - curve(t, extent);
    float side = dot(delta, normal) < 0.0 ? -1.0 : 1.0;
    return RibbonPoint(t, side * length(delta), normal);
}

struct Material { vec3 body; float opacity; vec3 atmosphere; float mistOpacity; };

// Shared by the infinity and all background loops: the same fluid, membrane,
// spectral streaks, shadows, mist, and edge lighting at every depth.
Material shade(RibbonPoint point, float phase, float activity, vec3 chosen,
               vec3 power, bool front, float depthLayer, RibbonColors palette) {
    float u = point.u;
    // A broad current travels continuously; all modulation is spatially and
    // temporally smooth. Integer harmonics match exactly across phase wrap.
    float rate = depthLayer == 0.0 ? 12.0 : (depthLayer == 1.0 ? 8.0 : (depthLayer == 2.0 ? 5.0 : (depthLayer == 3.0 ? 4.0 : 3.0)));
    float flow = u - rate * phase;
    float radius = 5.0 + 0.65 * sin(3.0 * u - 4.0 * phase) + 0.35 * sin(5.0 * u + 3.0 * phase);
    if (abs(point.distance) > radius + 19.0) return Material(vec3(0.0), 0.0, vec3(0.0), 0.0);
    float v = point.distance / radius;
    float coverage = 1.0 - feather(radius - 0.55, radius + 0.55, abs(point.distance));
    float roundness = exp(-1.4 * v * v);
    float edgeLight = pow(max(0.0, roundness * 0.83 - v * point.normal.y * 0.44), 6.0);

    float bend = 0.40 * sin(3.0 * flow + 0.55 * sin(2.0 * u + 5.0 * phase));
    float filamentA = exp(-square((v - bend) * 4.6));
    float filamentB = exp(-square((v + 0.38 * sin(2.0 * flow + 0.8) + 0.12) * 8.0));
    float membrane = 0.5 + 0.5 * sin(4.0 * flow + 2.5 * v + 0.7 * sin(3.0 * u - 7.0 * phase));
    float current = square(square(0.5 + 0.5 * cos(flow)));

    vec3 tint = mix(vec3(linearSRGB(0.24)), mix(chosen, vec3(linearSRGB(0.72)), 0.10), activity);
    vec3 spectralA = spectrum(flow + 0.45 * v, power, palette);
    vec3 spectralB = spectrum(flow + pi + 0.30 * sin(2.0 * u), power, palette);
    // C2-continuous depth at the tips, strongest on the back crossing.
    float rear = front ? 0.0 : feather(0.0, 0.85, -cos(u));
    float depth = 1.0 - 0.58 * rear;
    float surfaceOpacity = coverage * (0.90 - 0.28 * rear);
    vec3 body = tint * (0.26 + 0.32 * roundness + activity * (0.16 * membrane + 0.40 * current));
    body += activity * (mix(tint, spectralA, 0.78) * 0.60 * filamentA
                     + mix(tint, spectralB, 0.82) * 0.32 * filamentB) * (0.40 + 0.60 * current);
    body += activity * spectralB * 0.14 * roundness * (1.0 - membrane);
    body += mix(vec3(linearSRGB(0.05)), vec3(linearSRGB(0.18)), activity) * edgeLight;
    body += activity * linearSRGB(vec3(0.13, 0.14, 0.15)) * filamentA * current;
    body *= depth;
    // The narrow cores transmit their own hue rather than adding RGB light to
    // the body (which washed greens/cyans into the dominant pink/red). Most of
    // the ribbon still retains the fully mixed color around these fine strands.
    float filaments = filamentA + filamentB;
    vec3 prism = (spectralA * filamentA + spectralB * filamentB) / max(filaments, 0.00001);
    float transmission = activity * (1.0 - exp(-3.8 * filaments));
    body = mix(body, prism * (0.32 + 0.36 * roundness + 0.20 * current) * depth, transmission);

    // Vapor stays close to the ribbon, with feathered edges rather than a hard
    // mask. Its density flows along the same closed path as the internal fluid.
    float outside = abs(point.distance) - radius;
    float outer = 0.5 * (outside + sqrt(outside * outside + 0.35));
    float mistOffset = 2.1 + 1.1 * sin(3.0 * flow + 2.0 * v);
    float vapor = exp(-square((outer - mistOffset) / 3.2));
    float edgeFade = feather(radius - 1.0, radius + 1.4, abs(point.distance));
    float density = 0.45 + 0.55 * square(0.5 + 0.5 * sin(3.0 * flow + 1.2 * sin(u + 3.0 * phase)));
    float glow = exp(-outer * outer / 14.0);
    // Beer-Lambert transmittance: optical densities add; opacity does not.
    float opticalDepth = activity * edgeFade * (0.24 * vapor * density + 0.06 * glow);
    float mistOpacity = 1.0 - exp(-opticalDepth);
    vec3 atmosphere = mix(tint, spectralA, 0.28) * depth * mistOpacity;
    return Material(body, surfaceOpacity, atmosphere, mistOpacity);
}

struct CurveSample { vec2 point; vec2 tangent; vec2 curvature; };

CurveSample loopCurve(float u, vec2 extent, float phase, float depth) {
    float a = 0.12 * sin(max(1.0, 4.0 - depth) * phase + depth);
    float b = 0.10 * cos(max(1.0, 3.0 - depth) * phase + 2.0 * depth);
    float second = 2.0 * u + 0.5 * depth;
    float third = 3.0 * u - depth;
    return CurveSample(extent * vec2(sin(u) + a * sin(second), cos(u) + b * cos(third)),
            extent * vec2(cos(u) + 2.0 * a * cos(second), -sin(u) - 3.0 * b * sin(third)),
            extent * vec2(-sin(u) - 4.0 * a * sin(second), -cos(u) - 9.0 * b * cos(third)));
}

RibbonPoint nearestLoop(vec2 p, vec2 extent, float phase, float depth) {
    float u = atan(p.x / extent.x, p.y / extent.y);
    for (int i = 0; i < 6; ++i) {
        CurveSample c = loopCurve(u, extent, phase, depth);
        vec2 delta = c.point - p;
        float denominator = dot(c.tangent, c.tangent) + dot(delta, c.curvature);
        u -= clamp(dot(delta, c.tangent) / max(denominator, 40.0), -0.35, 0.35);
    }
    CurveSample c = loopCurve(u, extent, phase, depth);
    vec2 tangent = normalize(c.tangent);
    vec2 normal = vec2(-tangent.y, tangent.x);
    vec2 delta = p - c.point;
    return RibbonPoint(u, (dot(delta, normal) < 0.0 ? -1.0 : 1.0) * length(delta), normal);
}

vec4 materialLayer(Material m) {
    return over(vec4(m.body * m.opacity, m.opacity), vec4(m.atmosphere, m.mistOpacity));
}

vec4 renderLoop(vec2 p, vec2 extent, float phase, float activity,
                  vec3 chosen, vec3 power, float depth, RibbonColors palette) {
    RibbonPoint point = nearestLoop(p, extent, phase * 2.0, depth);
    Material m = shade(point, phase, activity, chosen, power, true, depth, palette);
    return materialLayer(m);
}

// Four closed loops in a stable viewport. Inverse mapping keeps transforms
// continuous in floating point BEFORE rasterization, rather than moving and
// rotating four magnified offscreen images through SwiftUI layout each frame.
vec4 backdrop(vec2 position, vec2 canvas, float phase, float activity,
                vec3 chosen, vec3 power, RibbonColors palette) {
    const float scales[4] = float[4](5.6, 4.6, 3.6, 2.8);
    const float opacity[4] = float[4](0.028, 0.044, 0.064, 0.090);
    const vec2 centers[4] = vec2[4](vec2(0.12, -0.06), vec2(0.82, 0.29), vec2(-0.12, 0.64), vec2(0.88, 1.0));
    const float tilt[4] = float[4](-0.20, 0.24, -0.32, 0.38);
    const float orbit[4] = float[4](0.4, 2.1, 3.8, 5.3);
    float reference = min(canvas.x, 900.0);
    vec4 result = vec4(0.0);
    for (int i = 0; i < 4; ++i) {
        float depth = 4.0 - float(i), rate = i < 2 ? 2.0 : 3.0;
        float progress = phase * rate + orbit[i];
        float angle = tilt[i] + 0.12 * sin(progress + 0.7);
        vec2 drift = vec2(0.10 * sin(progress) + 0.025 * sin(phase + orbit[i]),
                              0.065 * cos(progress) + 0.02 * sin(2.0 * phase + orbit[i]));
        vec2 center = canvas * (centers[i] + drift);
        // Slow changes in depth and tilt suggest floating in space. Every
        // transform is continuous and evaluated before rasterization; integer
        // phase harmonics also join smoothly across the four-minute wrap.
        float depthScale = 1.0 + 0.045 * sin(progress + 1.2);
        vec2 p = (position - center) * (200.0 / (reference * scales[i] * depthScale));
        float c = cos(angle), s = sin(angle);
        p = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
        p.y /= 0.90 + 0.08 * cos(progress + 0.4);
        // Conservative bound includes the maximum curve deformation and mist.
        if (abs(p.x) > 106.0 || abs(p.y) > 70.0) continue;
        float distanceFade = 0.93 + 0.07 * cos(progress + 0.8);
        vec4 layer = renderLoop(p, vec2(72.0, 39.68), phase, activity, chosen, power, depth, palette) * opacity[i] * distanceFade;
        result = over(layer, result);
    }
    return result;
}

vec4 renderInfinity(vec2 p, float phase, float activity, vec3 chosen,
                      vec3 power, RibbonColors palette) {
    vec2 extent = vec2(61.6, 25.65);
    RibbonPoint nearFront = nearest(p, extent, true);
    RibbonPoint nearBack = nearest(p, extent, false);
    Material back = shade(nearBack, phase, activity, chosen, power, false, 0.0, palette);
    Material front = shade(nearFront, phase, activity, chosen, power, true, 0.0, palette);
    vec4 frontLayer = materialLayer(front), backLayer = materialLayer(back);
    vec4 crossed = over(frontLayer, backLayer);
    // Only merge samples that converge on the SAME shared tip. Separate
    // portions of the curve keep their independently composited atmosphere.
    // Choosing a nearest half with a boolean produced a visible mist seam on
    // the equidistant centerline; both this blend and its gate are C2 smooth.
    float phaseGap = abs(atan(sin(nearFront.u - nearBack.u), cos(nearFront.u - nearBack.u)));
    float sharedTip = 1.0 - feather(0.08, 0.36, phaseGap);
    float frontShare = 1.0 - feather(-0.75, 0.75, abs(nearFront.distance) - abs(nearBack.distance));
    vec4 continuousTip = mix(backLayer, frontLayer, frontShare);
    return mix(crossed, continuousTip, sharedTip);
}

void main() {
    RibbonColors palette = RibbonColors(vec3[6](hues[0], hues[1], hues[2], hues[3], hues[4], hues[5]));
    vec2 p = vec2(gl_FragCoord.x, canvas.y - gl_FragCoord.y);
    vec4 result = ambience > 0.0 ? backdrop(p, canvas, phase, activity, chosen, power, palette) * ambience : vec4(0.0);
    if (infinityRect.z > 0.0 && infinityRect.w > 0.0) {
        vec2 q = p - infinityRect.xy - infinityRect.zw * 0.5;
        q /= max(0.001, min(infinityRect.z / 160.0, infinityRect.w / 90.0));
        if (abs(q.x) < 90.0 && abs(q.y) < 50.0) result = over(renderInfinity(q, phase, activity, chosen, power, palette), result);
    }
    fragColor = vec4(encodedSRGB(displayMap(result.rgb)), 1.0);
}
