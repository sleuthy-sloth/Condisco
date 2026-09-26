import SwiftUI

// MARK: - Hands-free review session
//
// For the car, the kitchen, or the walk: the prompt shows big, a "Hear
// it" button speaks it in the card's language on demand, the learner
// answers out loud, then reveals the answer and self-rates honestly.
// Same verdicts, same event pipeline, same SRS as the quiz — just no
// typing and no staring at the screen. Manual advance only, like
// everything else in Review.

struct HandsFreeCardView: View {
    let item: ReviewItem
    let position: Int
    let total: Int
    let languageCode: String
    let saveError: String?
    let onVerdict: (ReviewVerdict) -> Void

    @StateObject private var speaker = ShadowSpeaker()
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("\(item.courseTitle) · \(item.lessonTitle)")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                SessionDots(position: position, total: total)
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Listen & recall")
                            .font(DesignTokens.text(13, weight: .semibold))
                            .foregroundStyle(DesignTokens.muted)
                            .textCase(.uppercase)
                        Text(item.prompt)
                            .font(DesignTokens.text(20))
                            .foregroundStyle(DesignTokens.inkDeep)
                            .lineSpacing(4)
                        Button {
                            if speaker.isSpeaking {
                                speaker.stop()
                            } else {
                                speaker.speak(
                                    item.prompt, languageCode: languageCode)
                            }
                        } label: {
                            Label(
                                speaker.isSpeaking ? "Stop" : "Hear it",
                                systemImage: speaker.isSpeaking
                                    ? "stop.fill" : "headphones")
                                .font(DesignTokens.text(16, weight: .semibold))
                                .foregroundStyle(DesignTokens.stock)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DesignTokens.primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Synthesized course voice")
                        // Minimum 44pt hit area (text + padding lands just
                        // under it at current type sizes).
                        .frame(minHeight: 44)
                        .padding(.top, 2)
                        Text("Course voice (synthesized)")
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                        if !revealed {
                            Text("Say it out loud, then reveal the answer.")
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                            Button("Reveal answer") {
                                speaker.stop()
                                revealed = true
                            }
                            .font(DesignTokens.text(15, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                            // 44pt minimum hit area for the plain-text button.
                            .frame(minHeight: 44)
                            .padding(.top, 2)
                        }
                    }
                }
                if revealed {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Answer")
                                .font(DesignTokens.text(13, weight: .semibold))
                                .foregroundStyle(DesignTokens.muted)
                                .textCase(.uppercase)
                            Text(item.answerText)
                                .font(DesignTokens.text(17, weight: .semibold))
                                .foregroundStyle(DesignTokens.primaryStrong)
                                .lineSpacing(4)
                            if item.feedback != item.answerText {
                                Text(item.feedback)
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.ink)
                                    .lineSpacing(3)
                            }
                            Divider()
                                .padding(.vertical, 4)
                            Text("How did that go?")
                                .font(DesignTokens.text(14, weight: .semibold))
                                .foregroundStyle(DesignTokens.ink)
                            VerdictButtonRow(
                                saveError: saveError, onVerdict: onVerdict)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .onDisappear { speaker.stop() }
    }
}
