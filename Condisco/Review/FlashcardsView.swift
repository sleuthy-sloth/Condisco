import SwiftUI

// MARK: - Flashcard study mode
//
// The same due queue as Review, studied as flashcards: read the prompt,
// tap to flip for the answer, then rate yourself honestly. Verdicts
// travel through the same event pipeline as the quiz, so the SRS
// reschedules identically. No timers, no streaks, no scores.

struct FlashcardStudyView: View {
    let item: ReviewItem
    let position: Int
    let total: Int
    let saveError: String?
    let onVerdict: (ReviewVerdict) -> Void

    @State private var flipped = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("\(item.courseTitle) · \(item.lessonTitle)")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                SessionDots(position: position, total: total)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        flipped.toggle()
                    }
                } label: {
                    ZStack {
                        PaperCard { cardFace(front: true) }
                            .opacity(flipped ? 0 : 1)
                        PaperCard { cardFace(front: false) }
                            .rotation3DEffect(
                                .degrees(180), axis: (x: 0, y: 1, z: 0))
                            .opacity(flipped ? 1 : 0)
                    }
                    .rotation3DEffect(
                        .degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    flipped ? "Answer. Activate to hide it."
                        : "Prompt. Activate to reveal the answer.")

                if !flipped {
                    Text("Tap the card to flip it.")
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    VerdictButtonRow(saveError: saveError, onVerdict: onVerdict)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func cardFace(front: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(front ? "Prompt" : "Answer")
                .font(DesignTokens.text(13, weight: .semibold))
                .foregroundStyle(DesignTokens.muted)
                .textCase(.uppercase)
            if front {
                Text(item.prompt)
                    .font(DesignTokens.text(19))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 120, alignment: .topLeading)
            } else {
                Text(item.answerText)
                    .font(DesignTokens.text(19, weight: .semibold))
                    .foregroundStyle(DesignTokens.primaryStrong)
                    .lineSpacing(4)
                if item.feedback != item.answerText {
                    Text(item.feedback)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.ink)
                        .lineSpacing(3)
                }
            }
        }
    }
}

// MARK: - Shared verdict buttons

/// The honest self-rating row, shared by the quiz and the flashcards so
/// both modes look and behave identically.
struct VerdictButtonRow: View {
    let saveError: String?
    let onVerdict: (ReviewVerdict) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("How did that go?")
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            HStack(spacing: 10) {
                ForEach(
                    [ReviewVerdict.tryAgain, .close, .exact, .easy], id: \.rawValue
                ) { verdict in
                    Button(verdict.label) { onVerdict(verdict) }
                        .font(DesignTokens.text(14, weight: .semibold))
                        .foregroundStyle(
                            verdict == .tryAgain
                                ? DesignTokens.primary
                                : DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            verdict == .tryAgain
                                ? Color.clear
                                : DesignTokens.primary)
                        .cornerRadius(8)
                        .overlay(
                            verdict == .tryAgain
                                ? RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignTokens.primary, lineWidth: 1)
                                : nil)
                }
            }
            if let saveError {
                Text(saveError)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }
}
