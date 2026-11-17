import Foundation
import SpectrumAnalysis

/// Lifetime is retained by both the source node and the analysis worker.
/// C owns the SPSC synchronization; only the worker reads, only audio writes.
final class OutputSampleFeed: @unchecked Sendable {
    let pointer = BNCaptureCreate()
    @MainActor private var lease: UUID?
    @MainActor private(set) var isEnabled = false
    @MainActor lazy var spectrumWorker = SpectrogramWorker(feed: self)
    deinit { if let pointer { BNCaptureDestroy(pointer) } }

    @MainActor func begin() -> UUID {
        let id = UUID(); lease = id; isEnabled = pointer != nil
        if let pointer { BNCaptureSetEnabled(pointer, true) }
        return id
    }
    @MainActor func end(_ id: UUID) { if lease == id { stop() } }
    @MainActor func stop() {
        lease = nil; isEnabled = false
        if let pointer { BNCaptureSetEnabled(pointer, false) }
    }
    var publishedFrames: UInt64 { pointer.map(BNCapturePublishedFrames) ?? 0 }
}
