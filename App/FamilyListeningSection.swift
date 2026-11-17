import SwiftUI

/// Shared guidance for caregivers on every supported platform. Digital peak
/// protection is not a calibrated sound-pressure limit at a child's ear.
struct FamilyListeningSection: View {
    var body: some View {
        Section {
            Text("A broad, adjustable blanket of sound for your household, with babies, children and pets in mind. Children, dogs and cats may hear high frequencies you no longer notice. EverNoise keeps those upper sounds available, so you can shape a mix for the ones you care for as well as yourself.")
                .accessibilityIdentifier("familyHearingGuidance")
            Text("Hearing varies with age, species and individual sensitivity. EverNoise reaches the upper end of human hearing; dogs, cats and some other pets can hear higher still. It cannot cover their entire hearing range. What reaches their ears also depends on your speaker.")
            Text("For babies and children, keep the speaker as far from them as possible, use the lowest practical volume, and limit listening time. Do not raise the volume just because you cannot hear a high frequency. Ask your pediatrician about use with your child.")
                .accessibilityIdentifier("familyListeningGuidance")
            Text("For pets, begin quietly, watch their response, and let them move to a quiet space. Stop if the sound seems to bother them.")
            Text("Peak protection controls digital peaks; it does not measure sound at anyone’s ears or guarantee a safe listening level. EverNoise has no automatic time limit, so a caregiver needs to stop playback. The spectrogram shows the generated signal, not the sound level in the room.")
            #if os(tvOS)
            Text("Guidance: American Academy of Pediatrics, Preventing Excessive Noise Exposure (2023).")
                .font(AppTypography.footnote)
            #else
            Link("Pediatric listening guidance", destination: URL(string: "https://doi.org/10.1542/peds.2023-063752")!)
            #endif
        } header: {
            Text("For the ones you care for").font(AppTypography.heading)
        }
    }
}
