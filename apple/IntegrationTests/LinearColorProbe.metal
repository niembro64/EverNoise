#include <metal_stdlib>
using namespace metal;
// Independent reference probe for the shader-to-SwiftUI display boundary.
// Half of white's linear radiance should display as sRGB 0.73535698.
// This is an independent reference, not the production conversion helper.
[[ stitchable ]] half4 linearHalfProbe(float2 position, half4 source) {
    return half4(0.73535698h, 0.73535698h, 0.73535698h, 1.0h) * source.a;
}
