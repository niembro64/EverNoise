// Numeric reference probes run against the actual production Metal helpers.
import Foundation
import Metal

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let sourcePath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "App/RibbonShaders.metal"
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
let kernel = """
kernel void colorProbes(device float4 *out [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    if (i == 0) out[i] = over(float4(0.5,0,0,0.5), float4(0,0,1,1));
    if (i == 1) out[i] = over(float4(0,0,0.5,0.5), float4(0.5,0,0,0.5));
    if (i == 2) out[i] = over(float4(0.5), float4(0.5));
    if (i == 3) out[i] = over(float4(0,0,0,0.5), float4(1));
    if (i == 4) out[i] = float4(linearSRGB(0.5), linearSRGB(0.04045), encodedSRGB(0.5), 1);
    float4 a = float4(0.12,0.06,0.03,0.3), b = float4(0.02,0.1,0.07,0.2), c = float4(0.08,0.03,0.15,0.4);
    if (i == 5) out[i] = over(a, over(b,c)) - over(over(a,b),c);
    if (i == 6) {
        float t1 = exp(-0.2), t2 = exp(-0.3);
        out[i] = float4(over(float4(0,0,0,1-t1),float4(0,0,0,1-t2)).a, 1-exp(-0.5), 0, 1);
    }
    RibbonColors palette = {{float3(0.4,0.1,0.1),float3(0.3,0.2,0.05),float3(0.1,0.3,0.1),
        float3(0.05,0.3,0.3),float3(0.1,0.2,0.5),float3(0.3,0.1,0.3)}};
    if (i == 7 || i == 8) {
        RibbonPoint p = {i == 7 ? pi : pi/2, 0, float2(0,1)};
        Material front = shade(p, 0.3, 1, float3(0.2,0.1,0.15), float3(1,0.1,0.25), true, 0, palette);
        Material back = shade(p, 0.3, 1, float3(0.2,0.1,0.15), float3(1,0.1,0.25), false, 0, palette);
        out[i] = float4(back.body.x/front.body.x, back.opacity, front.opacity, 1);
    }
}
kernel void spatialJoinProbes(device float4 *out [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    RibbonColors palette = {{float3(0.4,0.1,0.1),float3(0.3,0.2,0.05),float3(0.1,0.3,0.1),
        float3(0.05,0.3,0.3),float3(0.1,0.2,0.5),float3(0.3,0.1,0.3)}};
    float x = float(i % 521) * 0.25 - 65;
    float phase = float(i / 521) * 2 * pi / 12;
    float4 below = renderInfinity(float2(x,-0.0001),phase,1,float3(0.2,0.1,0.15),float3(1,0.1,0.25),palette);
    float4 above = renderInfinity(float2(x,0.0001),phase,1,float3(0.2,0.1,0.15),float3(1,0.1,0.25),palette);
    out[i] = abs(float4(encodedSRGB(displayMap(above.rgb)),above.a)
               - float4(encodedSRGB(displayMap(below.rgb)),below.a));
}
"""
let library = try device.makeLibrary(source: source.replacingOccurrences(of: "[[ stitchable ]]", with: "") + kernel, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "colorProbes")!)
let output = device.makeBuffer(length: 9 * MemoryLayout<SIMD4<Float>>.stride)!
let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(pipeline); encoder.setBuffer(output, offset: 0, index: 0)
encoder.dispatchThreads(MTLSize(width: 9, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 9, height: 1, depth: 1))
encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
if let error = command.error { throw error }
let values = Array(UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: SIMD4<Float>.self), count: 9))
let expected: [SIMD4<Float>] = [SIMD4(0.5,0,0.5,1),SIMD4(0.25,0,0.5,0.75),SIMD4(repeating:0.75),SIMD4(0.5,0.5,0.5,1),
    SIMD4(0.214041140482,0.003130804954,0.735356983052,1),.zero,SIMD4(0.393469340287,0.393469340287,0,1),SIMD4(0.42,0.62,0.90,1),SIMD4(1,0.90,0.90,1)]
for i in 0..<9 {
    for c in 0..<4 { precondition(abs(values[i][c]-expected[i][c]) < 0.000002, "Probe \(i) component \(c): \(values[i]) != \(expected[i])") }
}
let spatialCount = 521 * 12
let spatialPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "spatialJoinProbes")!)
let spatialOutput = device.makeBuffer(length: spatialCount * MemoryLayout<SIMD4<Float>>.stride)!
let spatialCommand = queue.makeCommandBuffer()!, spatialEncoder = spatialCommand.makeComputeCommandEncoder()!
spatialEncoder.setComputePipelineState(spatialPipeline); spatialEncoder.setBuffer(spatialOutput, offset: 0, index: 0)
spatialEncoder.dispatchThreads(MTLSize(width: spatialCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
spatialEncoder.endEncoding(); spatialCommand.commit(); spatialCommand.waitUntilCompleted()
if let error = spatialCommand.error { throw error }
let spatialValues = Array(UnsafeBufferPointer(start: spatialOutput.contents().assumingMemoryBound(to: Float.self), count: spatialCount * 4))
let spatialMaximum = spatialValues.max()!
let spatialPassed = spatialMaximum < 0.0005
let record: [String: Any] = ["device":device.name,"probesPassed":9,"tolerance":0.000002,
    "spatialJoinPairs":spatialCount,"spatialJoinMaximumDelta":spatialMaximum,"spatialJoinLimit":0.0005,"spatialJoinPassed":spatialPassed,
    "checks":["Opaque source-over", "Transparent source-over and correct union alpha", "Two half-white layers give alpha 0.75", "Alpha is not gamma corrected", "Exact sRGB decoding", "Associative premultiplied composition", "Beer-Lambert transmittance", "Darker translucent rear crossing", "Continuous shared tips"],
    "values":values.map { [$0.x,$0.y,$0.z,$0.w] }]
let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/release-v18/color-audit.json"
try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: destination))
print("PASS: nine production-GPU color, alpha, transmittance and depth probes.")
print("Spatial join: \(spatialCount) pairs, maximum delta \(spatialMaximum), passed: \(spatialPassed)")
if !spatialPassed { exit(1) }
