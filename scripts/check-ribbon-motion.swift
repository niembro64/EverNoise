// Actual production Metal, sampled at 60 Hz. No screenshots or mock geometry.
import Foundation
import Metal
import Accelerate

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = try String(contentsOf: root.appendingPathComponent("App/RibbonShaders.metal"), encoding: .utf8)
let kernel = """
kernel void auditRibbon(device float4 *out [[buffer(0)]], constant float *v [[buffer(1)]],
                        constant float4 *colors [[buffer(2)]], uint2 pixel [[thread_position_in_grid]]) {
    uint width = uint(v[0]), height = uint(v[1]);
    if (pixel.x >= width || pixel.y >= height) return;
    float2 raster = float2(v[0], v[1]);
    float2 size = v[3] < 0.5 ? float2(v[4], v[5]) : raster;
    out[pixel.y * width + pixel.x] = float4(livingRibbon((float2(pixel) + 0.5) * size / raster, half4(1), size,
        v[2], 1, colors[0].xyz + colors[2].xyz * 0.0630957344 + colors[4].xyz * 0.25118864, float3(1, 0.0630957344, 0.25118864), v[3], 0,
        float2(v[4], v[5]), colors[0].xyz, colors[1].xyz, colors[2].xyz,
        colors[3].xyz, colors[4].xyz, colors[5].xyz,
        float4(24, v[4] < 600 ? 70 : 32, v[4] - 48, (v[4] - 48) * 9 / 16), 1));
}
"""
// Inline the exact production body into this audit kernel. Stitchability is a
// SwiftUI linkage attribute and is not needed for a direct compute call.
let library = try device.makeLibrary(source: source.replacingOccurrences(of: "[[ stitchable ]]", with: "") + "\n" + kernel, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "auditRibbon")!)
let paletteSource = try String(contentsOf: root.appendingPathComponent("App/NoisePalette.swift"), encoding: .utf8)
let regex = try NSRegularExpression(pattern: #"SIMD3\(([0-9.]+), ([0-9.]+), ([0-9.]+)\)"#)
let matches = regex.matches(in: paletteSource, range: NSRange(paletteSource.startIndex..., in: paletteSource))
let hues: [SIMD4<Float>] = matches.map { m in
    func linear(_ component: Int) -> Float {
        let c = Float((paletteSource as NSString).substring(with: m.range(at: component)))!
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return SIMD4(linear(1), linear(2), linear(3), 0)
}
precondition(hues.count == 6)
let colors = device.makeBuffer(bytes: hues, length: hues.count * MemoryLayout<SIMD4<Float>>.stride)!
let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/release-v17/motion-audit.json"
var results = [[String: Any]]()
for (label, width, height, shape, canvasW, canvasH) in [
    ("phone-background",640,1391,Float(2),Float(402),Float(874)),
    ("tablet-background",768,1024,Float(2),Float(1032),Float(1376)),
    ("phone-infinity",768,432,Float(0),Float(354),Float(199.125)),
    ("tablet-infinity",1024,576,Float(0),Float(984),Float(553.5)),
    ("phone-complete-scene",768,1670,Float(3),Float(402),Float(874)),
    ("tablet-complete-scene",1024,1365,Float(3),Float(1032),Float(1376))
] {
    let count = width * height * 4
    let output = device.makeBuffer(length: count * MemoryLayout<Float>.stride, options: .storageModeShared)!
    var previous = [Float](repeating: 0, count: count), difference = previous, previousDifference = previous, acceleration = previous
    var worstDelta: Float = 0, worstSecond: Float = 0, gpuTimes = [Double](), rendered = 0
    func render(_ seconds: Double, wrapTime: Bool = true) throws -> [Float] {
        // Foreground shader dimensions are points; positions must be sampled
        // in that same space. Background uses a viewport-to-canvas mapping.
        let time = wrapTime ? seconds.truncatingRemainder(dividingBy: 240) : seconds
        let values: [Float] = [Float(width), Float(height), Float(time * 2 * .pi / 240), shape, canvasW, canvasH]
        let command = queue.makeCommandBuffer()!, encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(output, offset: 0, index: 0)
        encoder.setBytes(values, length: values.count * MemoryLayout<Float>.stride, index: 1)
        encoder.setBuffer(colors, offset: 0, index: 2)
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        gpuTimes.append((command.gpuEndTime - command.gpuStartTime) * 1000)
        rendered += 1
        return Array(UnsafeBufferPointer(start: output.contents().assumingMemoryBound(to: Float.self), count: count))
    }
    // Sample ordinary phases and the exact wrap, including the last frame on
    // one side and first frames on the other; a full raster is compared.
    for epoch in [0.0, 60, 120, 180, 239] {
        for frame in 0...120 {
            let pixels = try render(epoch + Double(frame) / 60)
            precondition(pixels.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
            if frame > 0 {
                vDSP_vsub(previous, 1, pixels, 1, &difference, 1, vDSP_Length(count))
                var maximum: Float = 0
                vDSP_maxmgv(difference, 1, &maximum, vDSP_Length(count)); worstDelta = max(worstDelta, maximum)
                if frame > 1 {
                    vDSP_vsub(previousDifference, 1, difference, 1, &acceleration, 1, vDSP_Length(count))
                    vDSP_maxmgv(acceleration, 1, &maximum, vDSP_Length(count)); worstSecond = max(worstSecond, maximum)
                }
                previousDifference = difference
            }
            previous = pixels
        }
    }
    let first = try render(12), repeated = try render(12)
    precondition(first == repeated, "Identical phase must produce identical pixels")
    var visibleThirds = [Int](repeating: 0, count: 3)
    if shape == 2 {
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                if max(first[offset], max(first[offset + 1], first[offset + 2])) > 0.003 {
                    visibleThirds[min(2, y * 3 / height)] += 1
                }
            }
        }
        precondition(visibleThirds.allSatisfy { $0 > 100 }, "Ribbons must be visible throughout the screen")
    }
    let start = try render(0), wrapped = try render(240, wrapTime: false)
    vDSP_vsub(start, 1, wrapped, 1, &difference, 1, vDSP_Length(count))
    var wrapDifference: Float = 0
    vDSP_maxmgv(difference, 1, &wrapDifference, vDSP_Length(count))
    print("\(label): frame delta \(worstDelta), second difference \(worstSecond), phase endpoint \(wrapDifference)")
    fflush(stdout)
    // Float sin/cos at 2π is not bit-identical to zero; half-float storage
    // can then differ by two representable steps in the faint alpha range.
    // This bound is below 1/15 of one 8-bit step; the crossing itself must
    // also pass the frame-delta and acceleration limits below.
    precondition(wrapDifference < (shape == 2 ? 0.00025 : 0.001), "Phase endpoints must agree within half-float precision")
    // Absolute limits expose a spatial solver jump even if average frame
    // differences are small. Half-float output quantization is included.
    precondition(worstDelta < (shape == 2 ? 0.004 : 0.045), "Sudden pixel change: \(label) \(worstDelta)")
    precondition(worstSecond < (shape == 2 ? 0.002 : 0.02), "Sudden acceleration: \(label) \(worstSecond)")
    let times = gpuTimes.sorted()
    let result: [String: Any] = ["case": label,"frames":rendered,"widthPixels":width,"heightPixels":height,
        "maxFrameDelta":worstDelta,"maxSecondDifference":worstSecond,
        "gpuMedianMS":times[times.count/2],"gpuP95MS":times[Int(Double(times.count)*0.95)],
        "identicalPhasePixels":true,"maxPhaseEndpointDifference":wrapDifference,
        "visiblePixelsByVerticalThird":visibleThirds]
    print(result)
    results.append(result)
}
let record: [String: Any] = ["device":device.name,"framesPerSecondSampled":60,"measurements":results,
    "scope":"Host GPU shader continuity and cost; not physical iPhone cadence or battery qualification"]
let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted,.sortedKeys])
try data.write(to: URL(fileURLWithPath: destination))
print("PASS")
