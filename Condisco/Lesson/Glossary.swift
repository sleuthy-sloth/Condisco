import SwiftUI

// MARK: - Tap-a-word glossary

/// Normalizes a word for glossary lookup: lowercase, punctuation stripped.
func glossaryKey(_ word: String) -> String {
    word.lowercased().replacingOccurrences(
        of: "[.,!?;:“”«»()]", with: "", options: .regularExpression)
}

/// Builds the word → entry map backing tappable glosses.
func makeVocabularyMap(_ items: [VocabularyItem]) -> [String: VocabularyItem] {
    var map: [String: VocabularyItem] = [:]
    for item in items {
        map[glossaryKey(item.word)] = item
    }
    return map
}

/// Target-language text with tappable glossary words.
///
/// Words present in the pack vocabulary render underlined in the accent
/// color; tapping one reveals its meaning in a line below the text. Words
/// without an entry stay plain text — never a dead tap.
struct GlossableText: View {
    let text: String
    let vocabularyByWord: [String: VocabularyItem]
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .regular
    var textColor: Color = DesignTokens.ink
    var onGloss: () -> Void = {}

    @State private var glosses: [VocabularyItem] = []

    private var parts: [String] {
        // Split keeping whitespace so spacing survives rendering.
        Array(text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { [$0, " "] }.dropLast())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    if part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(" ")
                    } else if let entry = vocabularyByWord[glossaryKey(part)] {
                        Button(part) {
                            if !glosses.contains(where: { $0.id == entry.id }) {
                                glosses.append(entry)
                            }
                            onGloss()
                        }
                        .font(DesignTokens.text(fontSize, weight: fontWeight))
                        .foregroundStyle(DesignTokens.primaryStrong)
                        .underline()
                        .accessibilityLabel("Show meaning of \(entry.word)")
                    } else {
                        Text(part)
                            .font(DesignTokens.text(fontSize, weight: fontWeight))
                            .foregroundStyle(textColor)
                    }
                }
            }

            if !glosses.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(glosses, id: \.id) { gloss in
                        Text("\(gloss.word) — \(gloss.meaning)")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
            }
        }
    }
}
