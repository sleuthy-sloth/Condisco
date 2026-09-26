import SwiftUI
import UIKit

// MARK: - Shareable phrase cards
//
// A Warm Studio phrase card: the target phrase big in the display serif,
// its meaning below, and a quiet Condisco wordmark. Rendered off-screen with
// ImageRenderer and shared as a PNG through ShareLink. The same card backs
// the phrasebook's share action.

/// A phrase worth keeping: target text, its meaning, and the language.
struct ShareablePhrase: Hashable {
    var target: String
    var meaning: String
    var languageName: String
}

/// The card as drawn for sharing: 4:5 portrait.
struct PhraseCardView: View {
    let phrase: ShareablePhrase

    private var wordmark: String {
        phrase.languageName.isEmpty
            ? "CONDISCO"
            : "CONDISCO · \(phrase.languageName.uppercased())"
    }

    var body: some View {
        ZStack {
            DesignTokens.stock
            VStack(spacing: 0) {
                Rectangle()
                    .fill(DesignTokens.primary)
                    .frame(height: 14)
                Spacer()
                Text("\u{201C}")
                    .font(DesignTokens.display(120))
                    .foregroundStyle(DesignTokens.primary)
                    .opacity(0.25)
                    .padding(.bottom, -40)
                Text(phrase.target)
                    .font(DesignTokens.display(64))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 72)
                Text(phrase.meaning)
                    .font(DesignTokens.text(34))
                    .foregroundStyle(DesignTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 72)
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
}

/// A rendered card, ready for ShareLink.
struct SharedCard: Identifiable {
    let id = UUID()
    let image: Image
    let caption: String

    /// Wraps an already-rendered card image, for callers that draw their own
    /// card (e.g. the pair-practice card) and only need the ShareLink wrapper.
    init(image: Image, caption: String) {
        self.image = image
        self.caption = caption
    }

    @MainActor
    init(phrase: ShareablePhrase) {
        self.caption = "\(phrase.target) — \(phrase.meaning)"
        let renderer = ImageRenderer(content: PhraseCardView(phrase: phrase))
        renderer.scale = 1
        if let uiImage = renderer.uiImage {
            self.image = Image(uiImage: uiImage)
        } else {
            self.image = Image(systemName: "quote.bubble")
        }
    }
}

/// Small share button that renders the phrase card on tap and presents
/// the system share sheet.
struct PhraseShareButton: View {
    let phrase: ShareablePhrase
    @State private var sharedCard: SharedCard?

    var body: some View {
        Button {
            sharedCard = SharedCard(phrase: phrase)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.muted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share \"\(phrase.target)\" as an image")
        .sheet(item: $sharedCard) { card in
            ShareLink(
                item: card.image,
                preview: SharePreview(card.caption, image: card.image))
                .presentationDetents([.medium, .large])
        }
    }
}
