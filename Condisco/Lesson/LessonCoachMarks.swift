import SwiftUI

// MARK: - Lesson guide
//
// A one-time, dismissible overlay explaining the lesson controls
// people don't inherently know: the speaker button, the underlined
// words, the bookmark, and share. Shown on the first lesson step the
// learner ever opens, then never again.

struct LessonGuideOverlay: View {
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            PaperCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How lessons work")
                        .font(DesignTokens.display(22))
                        .foregroundStyle(DesignTokens.inkDeep)
                    guideRow(
                        icon: "speaker.wave.2",
                        title: "Hear it",
                        body: "Tap the speaker on any phrase to hear it spoken aloud."
                    )
                    guideRow(
                        icon: "underline",
                        title: "Tap a word",
                        body: "Underlined words reveal their meaning right where they sit."
                    )
                    guideRow(
                        icon: "bookmark",
                        title: "Save it",
                        body: "Keep a phrase in your phrasebook to revisit anytime."
                    )
                    guideRow(
                        icon: "square.and.arrow.up",
                        title: "Share it",
                        body: "Turn any phrase into a card you can send to a friend."
                    )
                    StudioPrimaryButton(label: "Got it", disabled: false, action: onDone)
                        .padding(.top, 4)
                }
            }
            .padding(28)
        }
    }

    private func guideRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(DesignTokens.primary)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(body)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
    }
}
