import SwiftUI

// MARK: - Vocabulary browser
//
// A reference view over one course's full vocabulary list: every word,
// searchable, with its meaning, part of speech, and an example sentence
// whose own words stay tappable through the shared glossary. Reached
// from the top of the course's lesson list.

/// One letter group in the vocabulary browser.
private struct WordSection: Identifiable {
    let letter: String
    let words: [VocabularyItem]
    var id: String { letter }
}

/// A word the browser is showing the detail for. Hashes by id so
/// `VocabularyItem` itself never needs `Hashable`.
private struct SelectedWord: Hashable {
    let id: String
    let item: VocabularyItem

    static func == (lhs: SelectedWord, rhs: SelectedWord) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct VocabularyBrowserView: View {
    let pack: CoursePack

    @State private var searchText = ""
    @State private var selected: SelectedWord?

    /// Words A–Z; search matches the word or its meaning.
    private var words: [VocabularyItem] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let list = pack.vocabulary.sorted {
            $0.word.lowercased() < $1.word.lowercased()
        }
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.word.lowercased().contains(query)
                || $0.meaning.lowercased().contains(query)
        }
    }

    /// Letter sections in A–Z order.
    private var sections: [WordSection] {
        var order: [String] = []
        var groups: [String: [VocabularyItem]] = [:]
        for item in words {
            let letter = String(item.word.prefix(1)).uppercased()
            if groups[letter] == nil {
                order.append(letter)
            }
            groups[letter, default: []].append(item)
        }
        return order.map { WordSection(letter: $0, words: groups[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            if words.isEmpty {
                EmptyStateView(
                    art: .search,
                    title: "No words match",
                    message: "Try another spelling, or search by meaning instead.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\(words.count) \(words.count == 1 ? "word" : "words")")
                            .font(DesignTokens.text(13, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                            .padding(.horizontal, 4)
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.letter)
                                    .font(DesignTokens.text(11, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(DesignTokens.muted)
                                    .padding(.horizontal, 4)
                                ForEach(section.words, id: \.id) { item in
                                    Button {
                                        selected = SelectedWord(id: item.id, item: item)
                                    } label: {
                                        wordRow(item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search words")
        .navigationDestination(item: $selected) { selection in
            VocabularyDetailView(item: selection.item, pack: pack)
        }
    }

    private func wordRow(_ item: VocabularyItem) -> some View {
        PaperCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.word)
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(item.meaning)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                    if !item.partOfSpeech.isEmpty {
                        Text(item.partOfSpeech)
                            .font(DesignTokens.text(12))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.muted)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

struct VocabularyDetailView: View {
    let item: VocabularyItem
    let pack: CoursePack

    private var subtitle: String {
        var parts: [String] = []
        if !item.partOfSpeech.isEmpty {
            parts.append(item.partOfSpeech)
        }
        if let gender = item.gender {
            parts.append(gender.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    private var exampleShareable: ShareablePhrase {
        ShareablePhrase(
            target: item.example,
            meaning: item.meaning,
            languageName: pack.language.displayName)
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.word)
                                .font(DesignTokens.display(28))
                                .foregroundStyle(DesignTokens.inkDeep)
                            Text(item.meaning)
                                .font(DesignTokens.text(17))
                                .foregroundStyle(DesignTokens.ink)
                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                        }
                    }
                    if !item.example.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EXAMPLE")
                                .font(DesignTokens.text(11, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(DesignTokens.muted)
                                .padding(.horizontal, 4)
                            PaperCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    GlossableText(
                                        text: item.example,
                                        vocabularyByWord: makeVocabularyMap(pack.vocabulary),
                                        fontSize: 17)
                                    HStack(spacing: 16) {
                                        PhraseSaveButton(
                                            phrase: exampleShareable,
                                            languageSlug: pack.language.slug,
                                            source: "Vocabulary",
                                            // The browser spans the whole pack: a
                                            // vocabulary item is not bound to a single
                                            // lesson (it can appear in several), so no
                                            // lesson id exists here — only the pack id
                                            // is genuine.
                                            sourcePackId: pack.id)
                                        PhraseShareButton(phrase: exampleShareable)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(item.word)
        .navigationBarTitleDisplayMode(.inline)
    }
}
