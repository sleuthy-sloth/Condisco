import SwiftUI
import UIKit

// MARK: - Lesson moments
//
// The polish layer around the lesson engine: a briefing before the first
// step, a recap when the lesson completes, trouble-spot revisits, and
// dialogue role-play. Observational only — no grading, no scores, no
// streaks. The engine and event log are untouched; this file is pure
// presentation plus the tiny haptic vocabulary the player uses.

// MARK: - Quiet haptics

/// The app's whole haptic vocabulary: a soft tap when an answer checks
/// out, a light tap moving between steps, a gentle confirmation when a
/// lesson finishes. Nothing ever fires on a mistake.
enum Haptics {
    static func correct() {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    static func stepComplete() {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func lessonComplete() {
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Lesson content helpers

/// The first example pairs of the lesson, in step order — the phrases the
/// briefing previews and the recap can honestly say were practiced.
func keyPhrases(for lesson: Lesson, pack: CoursePack, limit: Int = 4) -> [ConceptExample] {
    for step in lesson.steps {
        guard let activity = pack.activity(id: step.activityId),
              let stimulusId = activity.stimulusId,
              let stimulus = pack.stimulus(id: stimulusId) else { continue }
        if case .examples(_, let pairs) = stimulus, !pairs.isEmpty {
            return Array(pairs.prefix(limit))
        }
    }
    return []
}

/// The lesson's vocabulary ids resolved against the pack's word list —
/// what the briefing previews and the recap offers for the phrasebook.
/// Empty when the lesson carries no vocabulary.
func previewWords(
    for lesson: Lesson, pack: CoursePack, limit: Int = 8
) -> [VocabularyItem] {
    guard !lesson.vocabulary.isEmpty else { return [] }
    let byId = Dictionary(
        uniqueKeysWithValues: pack.vocabulary.map { ($0.id, $0) })
    return Array(lesson.vocabulary.compactMap { byId[$0] }.prefix(limit))
}

/// The lesson's dialogue turns, in step order. Empty when the lesson has
/// no dialogue — only conversation-family lessons offer role-play.
func dialogueTurns(for lesson: Lesson, pack: CoursePack) -> [DialogueTurn] {
    for step in lesson.steps {
        guard let activity = pack.activity(id: step.activityId),
              let stimulusId = activity.stimulusId,
              let stimulus = pack.stimulus(id: stimulusId) else { continue }
        if case .dialogue(_, let turns) = stimulus, !turns.isEmpty {
            return turns
        }
    }
    return []
}

// MARK: - Briefing

/// The doorway into a lesson: what you'll learn, how long it takes, the
/// key phrases, and anything good to know up front. Shown once, only for
/// brand-new lessons — resumes go straight back to the step.
struct LessonBriefingView: View {
    let lesson: Lesson
    let pack: CoursePack
    let stepCount: Int
    let keyPhrases: [ConceptExample]
    let onStart: () -> Void
    let onExit: () -> Void

    /// Up to 8 of the lesson's words for the preview section.
    private var words: [VocabularyItem] {
        previewWords(for: lesson, pack: pack)
    }

    /// How many of the lesson's words aren't shown in the preview.
    private var moreWordCount: Int {
        max(0, lesson.vocabulary.count - words.count)
    }

    private var wordIndices: [Int] {
        Array(0..<words.count)
    }

    private func briefingWordRow(_ item: VocabularyItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.word)
                .font(DesignTokens.text(16, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(item.meaning)
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    FamilyBadge(family: lesson.family)
                    Text(lesson.title)
                        .font(DesignTokens.display(28))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(lesson.objective)
                        .font(DesignTokens.text(16))
                        .foregroundStyle(DesignTokens.ink)
                }

                HStack(spacing: 24) {
                    briefStat("\(stepCount)", label: stepCount == 1 ? "step" : "steps")
                    briefStat("~\(lesson.estimatedMinutes)", label: "minutes")
                    briefStat(familyDisplayName(lesson.family), label: "lesson")
                }

                if let note = lesson.culturalNote, !note.isEmpty {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GOOD TO KNOW")
                                .font(DesignTokens.text(11, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(DesignTokens.primary)
                            Text(note)
                                .font(DesignTokens.text(15))
                                .foregroundStyle(DesignTokens.ink)
                        }
                    }
                }

                if !keyPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KEY PHRASES")
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.muted)
                        ForEach(Array(keyPhrases.enumerated()), id: \.offset) { _, pair in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.target)
                                    .font(DesignTokens.text(16, weight: .medium))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                Text(pair.meaning)
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORDS YOU'LL MEET")
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.muted)
                        ForEach(wordIndices, id: \.self) { index in
                            briefingWordRow(words[index])
                        }
                        if moreWordCount > 0 {
                            Text("+\(moreWordCount) more")
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                }

                Spacer(minLength: 4)

                StudioPrimaryButton(label: "Start lesson", disabled: false, action: onStart)
                HStack {
                    Spacer()
                    StudioSecondaryButton("Back to lessons", action: onExit)
                    Spacer()
                }
            }
            .padding(24)
        }
    }

    private func briefStat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DesignTokens.display(20))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(label.uppercased())
                .font(DesignTokens.text(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(DesignTokens.muted)
        }
    }
}

// MARK: - Recap

/// Everything the recap's save buttons hand the phrasebook for one
/// example pair, resolved from the lesson it came from. Carries the
/// pack and lesson ids so Saved rows can open their origin lesson —
/// the recap's `pack` and `lesson` are in scope at both call sites.
struct RecapPhraseSave {
    let phrase: ShareablePhrase
    let languageSlug: String
    let source: String
    let sourcePackId: String
    let sourceLessonId: String
}

/// Builds the recap save payload for a phrase pair. Pure, so the tests
/// can pin that phrases saved from the recap always carry the pack and
/// lesson ids that let phrasebook navigation route back to the lesson.
func recapPhraseSave(
    target: String, meaning: String, pack: CoursePack, lesson: Lesson
) -> RecapPhraseSave {
    RecapPhraseSave(
        phrase: ShareablePhrase(
            target: target,
            meaning: meaning,
            languageName: pack.language.displayName),
        languageSlug: pack.language.slug,
        source: lesson.title,
        sourcePackId: pack.id,
        sourceLessonId: lesson.id)
}

/// The landing after the last step: what was practiced, the phrases now
/// in hand, trouble spots offered for one more try, role-play for
/// conversation lessons, and the way onward.
struct LessonRecapView: View {
    let lesson: Lesson
    let pack: CoursePack
    let stepsDone: Int
    let stepsTotal: Int
    let troubleCount: Int
    let keyPhrases: [ConceptExample]
    let nextLesson: Lesson?
    /// The single most relevant correction from this run's mistakes, if any.
    let takeaway: String?
    /// Graded checks solved on the learner's own this run.
    let independentCount: Int
    /// Graded checks practiced with help this run (model shown, help used,
    /// or a self-compare against the model).
    let practiceCount: Int
    let onRevisitTroubleSpots: () -> Void
    let onNextLesson: (String) -> Void
    let onExit: () -> Void

    @State private var rolePlaying = false
    /// The pair practice card sheet (P3.4) for conversation lessons:
    /// locals-only, share-sheet prototype. Nothing persisted, nothing sent.
    @State private var pairPracticing = false
    /// Local "I tried it" reflection marker for mission lessons. Loaded from
    /// the kv table on appear; see `missionTakeOutsideCard` for the tradeoff.
    @State private var triedIt = false

    /// The kv key backing the "I tried it" marker: pack- and lesson-scoped.
    private var triedItKey: String {
        "condisco.mission-tried:\(pack.id):\(lesson.id)"
    }

    /// Up to 8 of the lesson's words, each saveable to the phrasebook.
    private var words: [VocabularyItem] {
        previewWords(for: lesson, pack: pack)
    }

    /// How many of the lesson's words aren't shown in the recap.
    private var moreWordCount: Int {
        max(0, lesson.vocabulary.count - words.count)
    }

    private var wordIndices: [Int] {
        Array(0..<words.count)
    }

    private var turns: [DialogueTurn] {
        dialogueTurns(for: lesson, pack: pack)
    }

    private var canRolePlay: Bool {
        lesson.family == .conversation && !turns.isEmpty
    }

    private func recapWordRow(_ item: VocabularyItem) -> some View {
        let save = recapPhraseSave(
            target: item.word, meaning: item.meaning,
            pack: pack, lesson: lesson)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.word)
                    .font(DesignTokens.text(16, weight: .medium))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text(item.meaning)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
            Spacer()
            PhraseSaveButton(
                phrase: save.phrase,
                languageSlug: save.languageSlug,
                source: save.source,
                sourcePackId: save.sourcePackId,
                sourceLessonId: save.sourceLessonId)
        }
    }

    /// Mission-only card: hands the learner the lesson's real-world task
    /// (the author's own objective line) and the first key phrase to take
    /// with them, plus a quiet "I tried it" reflection toggle.
    ///
    /// Tradeoff, stated plainly: the "tried it" marker lives in the kv
    /// table alone — it is not synced across devices and does not enter
    /// the event timeline or the data export. That is acceptable because
    /// the plan frames it as reflection, not evidence of proficiency, and
    /// the durable artifact (the saved phrase) already syncs.
    private func missionTakeOutsideCard(_ pair: ConceptExample) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("TAKE IT OUTSIDE")
                    .font(DesignTokens.text(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.primary)
                Text(lesson.objective)
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.target)
                            .font(DesignTokens.text(16, weight: .medium))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text(pair.meaning)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Spacer()
                    let save = recapPhraseSave(
                        target: pair.target, meaning: pair.meaning,
                        pack: pack, lesson: lesson)
                    PhraseSaveButton(
                        phrase: save.phrase,
                        languageSlug: save.languageSlug,
                        source: save.source,
                        sourcePackId: save.sourcePackId,
                        sourceLessonId: save.sourceLessonId)
                }
                Divider()
                    .overlay(DesignTokens.edgeSoft)
                Toggle("I tried it", isOn: Binding(
                    get: { triedIt },
                    set: { setTriedIt($0) }))
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.inkDeep)
                    .tint(DesignTokens.primary)
                    .accessibilityHint("Saved only on this device")
            }
        }
    }

    /// Persists the "I tried it" marker, store-per-tap like
    /// `PhraseSaveButton` — no view-model plumbing. Tried is the literal
    /// value "1"; anything else (absent, empty, deleted) reads as untried.
    private func setTriedIt(_ value: Bool) {
        triedIt = value
        Task { @MainActor in
            do {
                let store = try LearningStore.inDocuments()
                if value {
                    try store.kvSet(triedItKey, "1")
                } else {
                    try store.kvDelete(triedItKey)
                }
            } catch {
                // Quiet: the toggle keeps its state; the marker just
                // isn't persisted this time.
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lesson complete")
                            .font(DesignTokens.display(28))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text("Nice work on “\(lesson.title)”.")
                            .font(DesignTokens.text(16))
                            .foregroundStyle(DesignTokens.ink)
                        if !lesson.objective.isEmpty {
                            Text("Goal achieved: \(lesson.objective)")
                                .font(DesignTokens.text(15))
                                .foregroundStyle(DesignTokens.ink)
                        }
                        Text(stepsLine)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                        if checksDone > 0 {
                            Text(independenceLine)
                                .font(DesignTokens.text(14))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                    Spacer(minLength: 0)
                    Image("CondiscoBeeCompanion")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                }

                if !keyPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOU CAN NOW SAY")
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.primary)
                        Text("Use these outside the app — they're yours now.")
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                        ForEach(Array(keyPhrases.enumerated()), id: \.offset) { _, pair in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.target)
                                    .font(DesignTokens.text(16, weight: .medium))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                Text(pair.meaning)
                                    .font(DesignTokens.text(14))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if lesson.family == .mission,
                   !lesson.objective.isEmpty,
                   let firstPhrase = keyPhrases.first {
                    missionTakeOutsideCard(firstPhrase)
                }

                if let takeaway {
                    Text("Worth remembering: \(takeaway)")
                        .font(DesignTokens.text(14, weight: .medium))
                        .foregroundStyle(DesignTokens.inkDeep)
                }

                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORDS YOU MET")
                            .font(DesignTokens.text(11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(DesignTokens.primary)
                        ForEach(wordIndices, id: \.self) { index in
                            recapWordRow(words[index])
                        }
                        if moreWordCount > 0 {
                            Text("+\(moreWordCount) more")
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                }

                VStack(spacing: 12) {
                    if let next = nextLesson {
                        StudioPrimaryButton(label: "Next: \(next.title)", disabled: false) {
                            onNextLesson(next.id)
                        }
                    } else {
                        StudioPrimaryButton(label: "Back to lessons", disabled: false, action: onExit)
                    }
                    if troubleCount > 0 {
                        StudioSecondaryButton(
                            "Revisit \(troubleCount) trouble spot\(troubleCount == 1 ? "" : "s")",
                            action: onRevisitTroubleSpots)
                    }
                    if canRolePlay {
                        StudioSecondaryButton("Role-play the dialogue") {
                            rolePlaying = true
                        }
                    }
                    if lesson.family == .conversation {
                        StudioSecondaryButton("Pair practice card") {
                            pairPracticing = true
                        }
                    }
                    if nextLesson != nil {
                        Button("Back to lessons", action: onExit)
                            .font(DesignTokens.text(15, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .sheet(isPresented: $rolePlaying) {
            RolePlayView(
                turns: turns,
                languageCode: ShadowVoice.languageCode(for: pack.language.slug))
        }
        .sheet(isPresented: $pairPracticing) {
            PairPracticeView(
                turns: turns,
                languageName: pack.language.displayName)
        }
        .task {
            // Only the literal "1" counts as tried; absent and empty
            // both read as untried, so a kvDelete un-mark behaves like
            // the marker was never set.
            let value = (try? LearningStore.inDocuments().kvGet(triedItKey)) ?? nil
            triedIt = value == "1"
        }
    }

    private var stepsLine: String {
        var line = "\(stepsDone) of \(stepsTotal) steps practiced"
        if troubleCount > 0 {
            line += " · \(troubleCount) worth another look"
        }
        return line
    }

    /// Whether any real check landed this run; the honesty line only speaks
    /// when there is something to report (a resumed-complete lesson shows
    /// no counts rather than a misleading zero).
    private var checksDone: Int { independentCount + practiceCount }

    /// Plain, non-judgmental split between recall and practice-with-help for
    /// this run. Uses the same vocabulary as the step feedback ("solved on
    /// your own", "with help"); never a streak, never a judgment.
    private var independenceLine: String {
        if independentCount > 0 && practiceCount > 0 {
            return "Solved \(independentCount) on your own · practiced \(practiceCount) with help."
        }
        if independentCount > 0 {
            return "Solved \(independentCount) on your own."
        }
        return "Practiced \(practiceCount) with help."
    }
}

// MARK: - Role-play

/// Say the dialogue out loud, taking one role while the app voices the
/// other on demand. Manual advance only — no timers, no scoring, the same
/// contract as shadow mode.
struct RolePlayView: View {
    let turns: [DialogueTurn]
    let languageCode: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = ShadowSpeaker()
    @State private var role: String? = nil
    @State private var index = 0

    private var speakers: [String] {
        var seen: [String] = []
        for turn in turns where !seen.contains(turn.speaker) {
            seen.append(turn.speaker)
        }
        return seen
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if let role {
                    playView(role: role)
                } else {
                    rolePicker
                }
            }
            .navigationTitle("Role-play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear { speaker.stop() }
        }
    }

    private var rolePicker: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Choose your role")
                .font(DesignTokens.display(24))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("You say their lines out loud. Your partner's lines play whenever you want to hear them — no scoring, just practice.")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            ForEach(speakers, id: \.self) { name in
                StudioSecondaryButton("I'm \(name)") { role = name }
            }
            Spacer()
        }
        .padding(24)
    }

    private func playView(role: String) -> some View {
        let turn = turns[index]
        let mine = turn.speaker == role
        return VStack(spacing: 20) {
            Text("Line \(index + 1) of \(turns.count)")
                .font(DesignTokens.text(13, weight: .semibold))
                .foregroundStyle(DesignTokens.primary)
                .textCase(.uppercase)
            Spacer()
            PaperCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mine ? "YOUR LINE" : turn.speaker.uppercased())
                        .font(DesignTokens.text(11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(mine ? DesignTokens.primary : DesignTokens.muted)
                    Text(turn.text)
                        .font(DesignTokens.display(26))
                        .foregroundStyle(DesignTokens.inkDeep)
                    if let meaning = turn.meaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(DesignTokens.text(16))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    if mine {
                        Text("Say it out loud, then continue.")
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 6) {
                Button {
                    speaker.speak(turn.text, languageCode: languageCode)
                } label: {
                    Label(
                        speaker.isSpeaking ? "Speaking…" : (mine ? "Hear it" : "Hear them"),
                        systemImage: "speaker.wave.2.fill")
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(speaker.isSpeaking)
                .accessibilityHint("Synthesized course voice")
                Text("Course voice (synthesized)")
                    .font(DesignTokens.text(12))
                    .foregroundStyle(DesignTokens.muted)
            }
            Spacer()
            HStack {
                Button("Previous") { go(to: index - 1) }
                    .font(DesignTokens.text(16, weight: .semibold))
                    .foregroundStyle(index == 0 ? DesignTokens.muted : DesignTokens.primary)
                    .disabled(index == 0)
                Spacer()
                Button(index == turns.count - 1 ? "Done" : "Next") {
                    if index == turns.count - 1 {
                        dismiss()
                    } else {
                        go(to: index + 1)
                    }
                }
                .font(DesignTokens.text(16, weight: .semibold))
                .foregroundStyle(DesignTokens.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func go(to newIndex: Int) {
        speaker.stop()
        index = newIndex
    }
}

// MARK: - Pair practice card
//
// P3.4 demand-test prototype: the lesson dialogue as a two-sided,
// shareable card. One side hands the learner the role who speaks first
// (they open the dialogue), the other the responder (the partner opens).
// A flip swaps sides; a share button renders the current side with
// ImageRenderer and hands it to the same SharedCard/ShareLink pipeline
// the phrase cards use. Locals only — nothing is persisted, and the PNG
// leaves the device only through the system share sheet.
//
// Honesty contract: the card claims practice, never proficiency. No
// scores, no accuracy, no tracked state.

/// The distinct speakers of a dialogue, in speaking order — the first is
/// the role who opens the conversation. Mirrors RolePlayView's speaker
/// discovery; free so the tests can assert ordering.
func distinctSpeakers(in turns: [DialogueTurn]) -> [String] {
    var seen: [String] = []
    for turn in turns where !seen.contains(turn.speaker) {
        seen.append(turn.speaker)
    }
    return seen
}

/// The share preview caption for the pair card: plain course content only
/// — the language name and the dialogue lines themselves. Never a pack,
/// lesson, or device identifier; the tests guard exactly that.
func pairCardCaption(turns: [DialogueTurn], languageName: String) -> String {
    let base = languageName.isEmpty
        ? "Role-play card"
        : "\(languageName) role-play card"
    guard !turns.isEmpty else { return base }
    let lines = turns
        .map { "\($0.speaker): \($0.text)" }
        .joined(separator: " · ")
    return "\(base) — \(lines)"
}

/// The pair card as drawn for sharing: 4:5 portrait in the same visual
/// language as `PhraseCardView` — stock ground, terracotta rule, display
/// serif, quiet wordmark. Both roles' lines appear with speaker labels;
/// the learner's role is flagged "YOU" on its lines and named in the
/// header. `learnerRole` is that role — the card's "side" — so flipping
/// in `PairPracticeView` visibly changes the shared image.
struct PairPracticeCardView: View {
    let turns: [DialogueTurn]
    /// The role the learner reads on this side of the card. A role that
    /// speaks no line clears the "YOU" flags rather than mis-marking.
    let learnerRole: String?
    let languageName: String

    /// Very long dialogues get the first `cardTurnLimit` turns plus a
    /// "+N more lines" note instead of clipped text.
    private static let cardTurnLimit = 6

    private var wordmark: String {
        languageName.isEmpty
            ? "CONDISCO"
            : "CONDISCO · \(languageName.uppercased())"
    }

    private var visibleTurns: [DialogueTurn] {
        Array(turns.prefix(Self.cardTurnLimit))
    }

    private var extraTurnCount: Int {
        max(0, turns.count - Self.cardTurnLimit)
    }

    var body: some View {
        ZStack {
            DesignTokens.stock
            VStack(spacing: 0) {
                Rectangle()
                    .fill(DesignTokens.primary)
                    .frame(height: 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Practise this dialogue together")
                        .font(DesignTokens.text(22, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(DesignTokens.primary)
                        .textCase(.uppercase)
                        .padding(.top, 64)
                    if let role = resolvedLearnerRole {
                        HStack(spacing: 12) {
                            Text("YOUR ROLE")
                                .font(DesignTokens.text(20, weight: .semibold))
                                .tracking(3)
                                .foregroundStyle(DesignTokens.muted)
                            Text(role.uppercased())
                                .font(DesignTokens.text(24, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(DesignTokens.inkDeep)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 24)
                    }
                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(Array(visibleTurns.enumerated()), id: \.offset) { _, turn in
                            turnRow(turn)
                        }
                        if extraTurnCount > 0 {
                            Text("+\(extraTurnCount) more lines on the next card")
                                .font(DesignTokens.text(20, weight: .medium))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }
                    .padding(.top, 40)
                    Spacer(minLength: 48)
                    Text(wordmark)
                        .font(DesignTokens.text(24, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(DesignTokens.muted)
                        .padding(.bottom, 64)
                }
                .padding(.horizontal, 72)
            }
        }
        .frame(width: 1080, height: 1350)
    }

    /// Only flags lines when the role is actually on the card — a stale
    /// role never marks anything.
    private var resolvedLearnerRole: String? {
        guard let learnerRole,
              turns.contains(where: { $0.speaker == learnerRole }) else {
            return nil
        }
        return learnerRole
    }

    private func turnRow(_ turn: DialogueTurn) -> some View {
        let mine = turn.speaker == resolvedLearnerRole
        return VStack(alignment: .leading, spacing: 6) {
            Text(mine ? "YOU · \(turn.speaker.uppercased())"
                      : turn.speaker.uppercased())
                .font(DesignTokens.text(22, weight: .semibold))
                .tracking(2)
                .foregroundStyle(mine ? DesignTokens.primary : DesignTokens.muted)
            Text(turn.text)
                .font(DesignTokens.display(34))
                .foregroundStyle(DesignTokens.inkDeep)
                .minimumScaleFactor(0.6)
                .lineLimit(nil)
            if let meaning = turn.meaning, !meaning.isEmpty {
                Text(meaning)
                    .font(DesignTokens.text(22))
                    .foregroundStyle(DesignTokens.muted)
                    .minimumScaleFactor(0.6)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The two-sided pair practice card sheet. Shows the current side of the
/// card, a flip that swaps which role the learner reads (and therefore
/// whether they open the dialogue or answer), a line counter for reading
/// through, and a share button that exports the side as a PNG through the
/// system share sheet.
struct PairPracticeView: View {
    let turns: [DialogueTurn]
    let languageName: String

    @Environment(\.dismiss) private var dismiss
    /// The flip. true = the learner takes the role who speaks first and
    /// reads the opening line; false = the learner takes the next role
    /// and answers. Swapping roles is the card's "side".
    @State private var learnerReadsFirst = false
    /// The line the learner is reading, for the turn counter.
    @State private var index = 0
    @State private var sharedCard: SharedCard?

    private var speakers: [String] {
        distinctSpeakers(in: turns)
    }

    /// The role the learner reads on this side of the card.
    private var learnerRole: String? {
        guard let first = speakers.first else { return nil }
        if learnerReadsFirst { return first }
        return speakers.count > 1 ? speakers[1] : first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if turns.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Pair practice card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $sharedCard) { card in
                ShareLink(
                    item: card.image,
                    preview: SharePreview(card.caption, image: card.image))
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                cardPreview

                HStack(spacing: 16) {
                    Button {
                        learnerReadsFirst.toggle()
                        index = 0
                    } label: {
                        Label("Flip card", systemImage: "rectangle.2.swap")
                            .font(DesignTokens.text(15, weight: .medium))
                            .foregroundStyle(DesignTokens.ink)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(DesignTokens.stock)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignTokens.edge, lineWidth: 1.5)
                            )
                            .shadow(color: DesignTokens.ink, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Flip card: swap which role reads first")

                    Button {
                        sharedCard = makeSharedCard()
                    } label: {
                        Label("Share card", systemImage: "square.and.arrow.up")
                            .font(DesignTokens.text(16, weight: .semibold))
                            .foregroundStyle(DesignTokens.stock)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(DesignTokens.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DesignTokens.edge, lineWidth: 1.5)
                            )
                            .shadow(color: DesignTokens.ink, radius: 0, x: 3, y: 3)
                    }
                    .buttonStyle(.plain)
                }

                Text(roleLine)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Divider()
                    .overlay(DesignTokens.edgeSoft)

                Text("Line \(index + 1) of \(turns.count)")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                HStack {
                    Button("Previous") { go(to: index - 1) }
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(
                            index == 0 ? DesignTokens.muted : DesignTokens.primary)
                        .disabled(index == 0)
                    Spacer()
                    Button("Next") { go(to: index + 1) }
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(
                            index == turns.count - 1
                                ? DesignTokens.muted : DesignTokens.primary)
                        .disabled(index == turns.count - 1)
                }
                .buttonStyle(.plain)

                Text("Your lines are flagged “YOU”. Flip to swap roles. The card is just an image you share — nothing is saved or sent.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(24)
        }
    }

    private var roleLine: String {
        guard let role = learnerRole else { return "" }
        return learnerReadsFirst
            ? "Your part: \(role) — you open, your partner answers."
            : "Your part: \(role) — your partner opens, you answer."
    }

    /// The current side of the card, scaled to the screen width, with a
    /// side tag so the two sides read as distinct cards. The shared PNG
    /// is this exact card (minus the tag, which lives only on screen).
    private var cardPreview: some View {
        GeometryReader { geo in
            ZStack {
                PairPracticeCardView(
                    turns: turns,
                    learnerRole: learnerRole,
                    languageName: languageName)
                    .scaleEffect(geo.size.width / 1080, anchor: .top)
            }
            .frame(
                width: geo.size.width,
                height: geo.size.width * 1350 / 1080,
                alignment: .top)
        }
        .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
        .shadow(color: DesignTokens.ink, radius: 0, x: 6, y: 6)
        .overlay(alignment: .topLeading) {
            Text(learnerReadsFirst ? "SIDE B" : "SIDE A")
                .font(DesignTokens.text(12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(DesignTokens.stock)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DesignTokens.inkDeep)
                .cornerRadius(4)
                .padding(12)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(
            "Pair practice card.\(learnerRole.map { " You read \($0)." } ?? "")")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.muted)
            Text("No dialogue here yet")
                .font(DesignTokens.display(22))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("This lesson has no dialogue turns to put on a pair card.")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(24)
    }

    private func go(to newIndex: Int) {
        index = max(0, min(newIndex, turns.count - 1))
    }

    /// Renders the current side with ImageRenderer and hands it to the
    /// same SharedCard/ShareLink pipeline the phrase cards use. The
    /// caption is pure course content (see `pairCardCaption`).
    @MainActor
    private func makeSharedCard() -> SharedCard {
        let card = PairPracticeCardView(
            turns: turns,
            learnerRole: learnerRole,
            languageName: languageName)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        let caption = pairCardCaption(turns: turns, languageName: languageName)
        if let uiImage = renderer.uiImage {
            return SharedCard(image: Image(uiImage: uiImage), caption: caption)
        }
        return SharedCard(
            image: Image(systemName: "bubble.left.and.bubble.right"),
            caption: caption)
    }
}
