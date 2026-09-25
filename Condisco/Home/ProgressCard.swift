import SwiftUI
import UIKit

// MARK: - Shareable progress card
//
// A Warm Studio progress card for the focus language: three big serif
// numbers — lessons finished, phrases kept, practice days — with quiet
// labels and a CONDISCO wordmark. Rendered off-screen with ImageRenderer and
// shared as a PNG through ShareLink. Observational wording only: never a
// streak, never a score.

/// The numbers on a progress card, all observational counts.
struct ShareableProgress {
    let languageName: String
    let phrasesKept: Int
    let practiceDays: Int
    let lessonsFinished: Int
}

/// The card as drawn for sharing: 4:5 portrait.
struct ProgressCardView: View {
    let progress: ShareableProgress

    private var wordmark: String {
        progress.languageName.isEmpty
            ? "CONDISCO"
            : "CONDISCO · \(progress.languageName.uppercased())"
    }

    var body: some View {
        ZStack {
            DesignTokens.stock
            VStack(spacing: 0) {
                Rectangle()
                    .fill(DesignTokens.primary)
                    .frame(height: 14)
                Spacer()
                Text("So far")
                    .font(DesignTokens.text(28, weight: .medium))
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.bottom, 44)
                progressStat(
                    value: "\(progress.lessonsFinished)",
                    label: progress.lessonsFinished == 1
                        ? "lesson finished" : "lessons finished")
                progressStat(
                    value: "\(progress.phrasesKept)",
                    label: progress.phrasesKept == 1
                        ? "phrase kept" : "phrases kept")
                progressStat(
                    value: "\(progress.practiceDays)",
                    label: progress.practiceDays == 1
                        ? "day of \(progress.languageName)"
                        : "days of \(progress.languageName)")
                Spacer()
                Text(wordmark)
                    .font(DesignTokens.text(24, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(DesignTokens.muted)
                    .padding(.bottom, 64)
            }
        }
        .frame(width: 1080, height: 1350)
    }

    private func progressStat(value: String, label: String) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(DesignTokens.display(110))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(label)
                .font(DesignTokens.text(34))
                .foregroundStyle(DesignTokens.muted)
        }
        .padding(.bottom, 48)
    }
}

/// A rendered card, ready for ShareLink.
struct SharedProgressCard: Identifiable {
    let id = UUID()
    let image: Image
    let caption: String

    @MainActor
    init(progress: ShareableProgress) {
        self.caption =
            "\(progress.lessonsFinished) lessons finished · \(progress.phrasesKept) phrases kept · \(progress.practiceDays) days of \(progress.languageName)"
        let renderer = ImageRenderer(content: ProgressCardView(progress: progress))
        renderer.scale = 1
        if let uiImage = renderer.uiImage {
            self.image = Image(uiImage: uiImage)
        } else {
            self.image = Image(systemName: "chart.bar")
        }
    }
}

/// Small share button that renders the progress card on tap and presents
/// the system share sheet.
struct ProgressShareButton: View {
    let progress: ShareableProgress
    @State private var sharedCard: SharedProgressCard?

    var body: some View {
        Button {
            sharedCard = SharedProgressCard(progress: progress)
        } label: {
            Label("Share your journey", systemImage: "square.and.arrow.up")
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(DesignTokens.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share your progress as an image")
        .sheet(item: $sharedCard) { card in
            ShareLink(
                item: card.image,
                preview: SharePreview(card.caption, image: card.image))
                .presentationDetents([.medium, .large])
        }
    }
}
