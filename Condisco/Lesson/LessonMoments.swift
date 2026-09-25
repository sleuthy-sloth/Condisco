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
    let onRevisitTroubleSpots: () -> Void
    let onNextLesson: (String) -> Void
    let onExit: () -> Void

    @State private var rolePlaying = false

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
        HStack(alignment: .top, spacing: 12) {
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
                phrase: ShareablePhrase(
                    target: item.word,
                    meaning: item.meaning,
                    languageName: pack.language.displayName),
                languageSlug: pack.language.slug,
                source: lesson.title)
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
                        Text(stepsLine)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
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
    }

    private var stepsLine: String {
        var line = "\(stepsDone) of \(stepsTotal) steps practiced"
        if troubleCount > 0 {
            line += " · \(troubleCount) worth another look"
        }
        return line
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
