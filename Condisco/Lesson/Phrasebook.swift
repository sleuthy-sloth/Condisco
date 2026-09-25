import SwiftUI

// MARK: - Phrasebook
//
// The learner's own collection: any example pair or transcript phrase can
// be bookmarked into Saved, newest first and grouped by language. Syncs
// across devices through CloudKit with delete tombstones, like checkpoints.

extension SavedPhrase {
    var shareable: ShareablePhrase {
        ShareablePhrase(
            target: target, meaning: meaning, languageName: languageName)
    }
}

/// Bookmark toggle shown beside the share button on phrase cards.
struct PhraseSaveButton: View {
    let phrase: ShareablePhrase
    let languageSlug: String
    let source: String
    /// Deep-link targets, carried onto the saved row so the phrasebook can
    /// open the lesson the phrase came from. Worker 3 fills these at the
    /// call sites; empty until then and everything still compiles.
    let sourcePackId: String = ""
    let sourceLessonId: String = ""

    @State private var isSaved = false

    private var phraseId: String {
        LearningStore.savedPhraseId(
            languageSlug: languageSlug,
            target: phrase.target,
            meaning: phrase.meaning)
    }

    var body: some View {
        Button {
            Task { @MainActor in
                do {
                    let store = try LearningStore.inDocuments()
                    if isSaved {
                        try store.unsavePhrase(id: phraseId)
                        isSaved = false
                    } else {
                        try store.savePhrase(SavedPhrase(
                            id: phraseId,
                            languageSlug: languageSlug,
                            languageName: phrase.languageName,
                            target: phrase.target,
                            meaning: phrase.meaning,
                            source: source,
                            sourcePackId: sourcePackId,
                            sourceLessonId: sourceLessonId,
                            savedAt: Date()))
                        isSaved = true
                    }
                } catch {
                    // Quiet: the button simply doesn't change state.
                }
            }
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(isSaved ? DesignTokens.primary : DesignTokens.muted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from phrasebook" : "Save to phrasebook")
        .task {
            let id = phraseId
            isSaved = (try? LearningStore.inDocuments().isPhraseSaved(id: id)) ?? false
        }
    }
}

@MainActor
final class SavedModel: ObservableObject {
    @Published var phrases: [SavedPhrase] = []
    @Published var isLoading = true

    func load() {
        phrases = (try? LearningStore.inDocuments().savedPhrases()) ?? []
        isLoading = false
    }

    func remove(_ phrase: SavedPhrase) {
        try? LearningStore.inDocuments().unsavePhrase(id: phrase.id)
        phrases.removeAll { $0.id == phrase.id }
    }
}

struct SavedView: View {
    @Binding var section: ReviewSection
    @StateObject private var model = SavedModel()
    @EnvironmentObject private var deepLink: DeepLinkRouter
    @State private var searchText = ""
    /// Source filter (lesson or track title); nil shows everything.
    @State private var situation: String? = nil

    /// Distinct saved-phrase sources, A–Z. Older saves predate source
    /// labels and appear only under "All".
    private var situations: [String] {
        Array(Set(model.phrases.map(\.source).filter { !$0.isEmpty })).sorted()
    }

    private var filtered: [SavedPhrase] {
        model.phrases.filter { phrase in
            if let situation, phrase.source != situation { return false }
            guard !searchText.isEmpty else { return true }
            return phrase.target.localizedCaseInsensitiveContains(searchText)
                || phrase.meaning.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Phrases grouped by language, languages in recency order.
    private var sections: [PhraseSection] {
        var order: [String] = []
        var groups: [String: [SavedPhrase]] = [:]
        for phrase in filtered {
            if groups[phrase.languageName] == nil {
                order.append(phrase.languageName)
            }
            groups[phrase.languageName, default: []].append(phrase)
        }
        return order.map { PhraseSection(language: $0, phrases: groups[$0] ?? []) }
    }

    /// One language group in the phrase list. A struct (not a tuple) so
    /// the list can identify sections without tuple key paths, which
    /// Swift key paths don't support.
    private struct PhraseSection: Identifiable {
        let language: String
        let phrases: [SavedPhrase]
        var id: String { language }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if model.isLoading {
                    ProgressView()
                        .tint(DesignTokens.primary)
                } else if model.phrases.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    noMatchState
                } else {
                    phraseList
                }
            }
            .navigationTitle("Review")
            .safeAreaInset(edge: .top, spacing: 0) {
                ReviewSectionPicker(selection: $section)
            }
            .searchable(text: $searchText, prompt: "Search phrases")
        }
        .task { model.load() }
    }

    private var phraseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(filtered.count) \(filtered.count == 1 ? "phrase" : "phrases") kept")
                        .font(DesignTokens.text(13, weight: .medium))
                        .foregroundStyle(DesignTokens.muted)
                    Text("Take them anywhere — export your phrasebook as an Anki deck.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                    AnkiExportButton(phrases: model.phrases)
                }
                .padding(.horizontal, 4)
                if !situations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            situationChip(label: "All", selected: situation == nil) {
                                situation = nil
                            }
                            ForEach(situations, id: \.self) { source in
                                situationChip(
                                    label: source,
                                    selected: situation == source) {
                                    situation = source
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.language.uppercased())
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.muted)
                            .padding(.horizontal, 4)
                        ForEach(section.phrases) { phrase in
                            phraseRow(phrase)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable { model.load() }
    }

    private func phraseRow(_ phrase: SavedPhrase) -> some View {
        PaperCard {
            HStack(alignment: .top, spacing: 12) {
                phraseText(phrase)
                Spacer()
                VStack(spacing: 14) {
                    PhraseShareButton(phrase: phrase.shareable)
                    Button {
                        model.remove(phrase)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \"\(phrase.target)\" from phrasebook")
                }
            }
        }
    }

    /// The phrase's text area. Tapping opens the lesson the phrase came
    /// from, when we know it — the open-tap stays on the text, never the
    /// whole row, so it can't clash with the trash button.
    @ViewBuilder
    private func phraseText(_ phrase: SavedPhrase) -> some View {
        let text = VStack(alignment: .leading, spacing: 4) {
            Text(phrase.target)
                .font(DesignTokens.text(16, weight: .semibold))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(phrase.meaning)
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
            if !phrase.source.isEmpty {
                Text(phrase.source)
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if !phrase.sourceLessonId.isEmpty {
            Button { openLesson(for: phrase) } label: { text }
                .buttonStyle(.plain)
                .accessibilityLabel("Open lesson for \"\(phrase.target)\"")
                .accessibilityHint("Opens the lesson this phrase was saved from")
        } else {
            text
        }
    }

    /// Opens the saved phrase's source lesson through the deep-link
    /// router. When the phrase predates deep-link ids (empty pack id),
    /// falls back to finding the pack that holds the lesson id.
    /// Best-effort: an unresolvable lesson simply does nothing.
    private func openLesson(for phrase: SavedPhrase) {
        Task { @MainActor in
            let packId: String
            if !phrase.sourcePackId.isEmpty {
                packId = phrase.sourcePackId
            } else if let pack = (try? PackLoader.loadPacks())?.first(where: {
                $0.lessons.contains(where: { $0.id == phrase.sourceLessonId })
            }) {
                packId = pack.id
            } else {
                return
            }
            guard let url = URL(
                string: "condisco://lesson/\(packId)/\(phrase.sourceLessonId)")
            else { return }
            deepLink.handle(url: url)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            art: .phrases,
            title: "No saved phrases yet",
            message: "Tap the bookmark on any example or transcript phrase to keep it here.")
    }

    private var noMatchState: some View {
        EmptyStateView(
            art: .search,
            title: "No phrases match",
            message: "Try a different search, or clear the situation filter.",
            actionLabel: "Clear filters") {
                searchText = ""
                situation = nil
            }
    }

    private func situationChip(
        label: String, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.text(14, weight: .semibold))
                .foregroundStyle(selected ? DesignTokens.stock : DesignTokens.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? DesignTokens.primary : DesignTokens.stock)
                .cornerRadius(9)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Color.clear : DesignTokens.stock3, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
