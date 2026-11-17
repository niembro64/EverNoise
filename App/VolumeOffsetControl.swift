import SwiftUI
import PlaybackCore

struct VolumeOffsetControl: View {
    let audio: AudioService

    var body: some View {
        #if os(tvOS)
        Picker("Volume offset", selection: Binding(get: { audio.volumeOffsetDB }, set: { audio.setVolumeOffsetDB($0) })) {
            ForEach(Array(VolumeOffset.range), id: \.self) { value in
                Text(VolumeOffset.label(value)).tag(value)
            }
        }
        .accessibilityIdentifier("volumeOffsetPicker")
        #else
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volume offset")
                Spacer()
                Text(VolumeOffset.label(audio.volumeOffsetDB))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("volumeOffsetValue")
            }
            Slider(value: Binding(get: { Double(audio.volumeOffsetDB) },
                                  set: { audio.setVolumeOffsetDB(Int($0.rounded())) }),
                   in: Double(VolumeOffset.range.lowerBound)...Double(VolumeOffset.range.upperBound), step: 1) {
                Text("Volume offset")
            }
            .accessibilityValue(VolumeOffset.label(audio.volumeOffsetDB))
            .accessibilityIdentifier("volumeOffsetSlider")
            HStack {
                Text("Quieter")
                Spacer()
                Text("Louder")
            }
            .font(AppTypography.footnote)
            .foregroundStyle(.secondary)
        }
        #endif
    }
}
