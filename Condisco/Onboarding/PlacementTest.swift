import SwiftUI

// MARK: - Placement test
//
// A short, calm check for learners who don't start from zero. Questions
// are built from the pack's own example phrases — no extra content to
// author — sampling lessons across the whole course. The result maps to
// the lesson we'd start them at. Nothing is marked complete, nothing is
// skipped: the recommendation is a badge on the lesson list, and the
// learner always keeps the final say.

struct PlacementQuestion: Identifiable {
    let id = UUID()
    let target: String
    let options: [String]
    let correctIndex: Int
    let lessonIndex: Int
}

/// How far into the course a placement question comes from, in plain
/// words for the reason line.
enum PlacementBand: String, CaseIterable {
    case early = "the early lessons"
    case middle = "the middle of the course"
    case late = "the later lessons"

    /// "a, b, and c" joining for the reason line.
    static func joining(_ bands: [PlacementBand]) -> String {
        switch bands.count {
        case 0: return ""
        case 1: return bands[0].rawValue
        case 2: return "\(bands[0].rawValue) and \(bands[1].rawValue)"
        default:
            let rest = bands.dropLast().map(\.rawValue).joined(separator: ", ")
            return "\(rest), and \(bands.last!.rawValue)"
        }
    }
}

/// What the placement check recommends, and why. The lesson id is what
/// `PlacementStore` persists — the rest feeds the result screen and the
/// placement tests.
struct PlacementRecommendation {
    let lesson: Lesson
    let correctCount: Int
    let totalCount: Int
    /// Weighted score 0...1: every answer counts, and questions sampled
    /// from later in the course carry more weight.
    let score: Double
    /// Bands (early/middle/late) where the learner answered at least half
    /// correctly. Feeds the honest one-liner under the result.
    let strongBands: [PlacementBand]

    /// The honest one-liner: what was measured, and why this lesson.
    /// Never claims precision the check doesn't have.
    var reason: String {
        if correctCount == totalCount {
            return "A clean sweep — every answer right. We'd start you near the end for a victory lap; everything before it is still there to revisit."
        }
        if correctCount == 0 {
            return "A fresh start is the kindest one — we'd begin at the very first lesson and build up from there."
        }
        var text = "You knew \(correctCount) of \(totalCount)."
        if strongBands.isEmpty {
            text += " We'd start you near the beginning and build up from there."
        } else {
            text += " Strong through \(PlacementBand.joining(strongBands)) — we'd start you just past the hardest stretch you showed you know."
        }
        return text
    }
}

enum PlacementBuilder {
    static let questionCount = 8

    /// One question per spread-out bucket of the pack's example
    /// phrases, in lesson order. Distractors are meanings of other
    /// phrases. Returns fewer than `questionCount` when the pack is
    /// thin; empty when there is nothing to ask about.
    static func build(pack: CoursePack) -> [PlacementQuestion] {
        let stimuliById = Dictionary(
            uniqueKeysWithValues: pack.stimuli.map { ($0.id, $0) })
        let activitiesById = Dictionary(
            uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })

        var candidates: [(lessonIndex: Int, pair: ConceptExample)] = []
        for (lessonIndex, lesson) in pack.lessons.enumerated() {
            for step in lesson.steps {
                guard let activity = activitiesById[step.activityId],
                      let stimulusId = activity.stimulusId,
                      let stimulus = stimuliById[stimulusId],
                      case .examples(_, let pairs) = stimulus
                else { continue }
                for pair in pairs {
                    candidates.append((lessonIndex, pair))
                }
            }
        }
        // Dedupe by target phrase, keeping the earliest lesson.
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.pair.target).inserted }
        guard unique.count >= 4 else { return [] }

        let count = min(questionCount, unique.count)
        let allMeanings = unique.map { $0.pair.meaning }
        var questions: [PlacementQuestion] = []
        for i in 0..<count {
            let candidate = unique[i * unique.count / count]
            let distractors = allMeanings
                .filter { $0 != candidate.pair.meaning }
                .shuffled()
                .prefix(3)
            guard distractors.count == 3 else { continue }
            let options = ([candidate.pair.meaning] + distractors).shuffled()
            guard let correct = options.firstIndex(of: candidate.pair.meaning)
            else { continue }
            questions.append(PlacementQuestion(
                target: candidate.pair.target,
                options: options,
                correctIndex: correct,
                lessonIndex: candidate.lessonIndex
            ))
        }
        return questions
    }

    /// The score behind a recommendation: every answer counts, weighted
    /// by how far into the course its question comes from. A
    /// first-question miss no longer wipes out seven harder correct
    /// answers. Kept pure (no pack) so tests can assert the math.
    static func score(
        questions: [PlacementQuestion], correctIds: Set<UUID>
    ) -> Double {
        let total = questions
            .reduce(0.0) { $0 + Double($1.lessonIndex + 1) }
        guard total > 0 else { return 0 }
        let earned = questions
            .filter { correctIds.contains($0.id) }
            .reduce(0.0) { $0 + Double($1.lessonIndex + 1) }
        return earned / total
    }

    /// Maps a score 0...1 onto a lesson index. Never past `victoryIndex`:
    /// a near-perfect run shouldn't outrank a perfect one.
    static func lessonIndex(
        forScore score: Double, lessonCount: Int, victoryIndex: Int
    ) -> Int {
        guard lessonCount > 0 else { return 0 }
        let capped = min(max(0, score), 1)
        let raw = Int((capped * Double(lessonCount)).rounded())
        return min(raw, max(0, victoryIndex))
    }

    /// The lesson we'd start them at: every answer counts, weighted by
    /// course position, and mapped proportionally onto the course. A
    /// clean sweep lands on the first lesson of the final unit — a
    /// victory lap, not the very last lesson. A blank sheet starts at
    /// the very beginning.
    static func recommend(
        pack: CoursePack,
        questions: [PlacementQuestion],
        correctIds: Set<UUID>
    ) -> PlacementRecommendation? {
        guard !questions.isEmpty, !pack.lessons.isEmpty else { return nil }
        let score = score(questions: questions, correctIds: correctIds)
        let correctCount = questions
            .filter { correctIds.contains($0.id) }.count

        // Victory-lap lesson: the first lesson of the final unit.
        let lastUnitId = pack.lessons.last?.unitId
        let victoryIndex = pack.lessons.firstIndex {
            $0.unitId == lastUnitId
        } ?? pack.lessons.count - 1

        let lesson: Lesson
        if correctCount == questions.count {
            lesson = pack.lessons[victoryIndex]
        } else {
            lesson = pack.lessons[lessonIndex(
                forScore: score,
                lessonCount: pack.lessons.count,
                victoryIndex: victoryIndex)]
        }

        // Bands for the reason line: thirds of the question set, in
        // lesson order.
        let ordered = questions.sorted { $0.lessonIndex < $1.lessonIndex }
        let bandSize = max(1, (ordered.count + 2) / 3)
        var strongBands: [PlacementBand] = []
        for (i, band) in PlacementBand.allCases.enumerated() {
            let slice = Array(ordered.dropFirst(i * bandSize).prefix(bandSize))
            guard !slice.isEmpty else { continue }
            let hits = slice.filter { correctIds.contains($0.id) }.count
            if hits * 2 >= slice.count { strongBands.append(band) }
        }

        return PlacementRecommendation(
            lesson: lesson,
            correctCount: correctCount,
            totalCount: questions.count,
            score: score,
            strongBands: strongBands)
    }
}

// MARK: - Placement persistence

/// The recommendation survives as a quiet badge on the lesson list.
/// It is a suggestion, never a gate.
enum PlacementStore {
    static func key(for packId: String) -> String {
        "condisco.placement.\(packId)"
    }

    static func recommendedLessonId(packId: String) -> String? {
        UserDefaults.standard.string(forKey: key(for: packId))
    }

    static func save(packId: String, lessonId: String) {
        UserDefaults.standard.set(lessonId, forKey: key(for: packId))
    }
}

// MARK: - Placement test view

struct PlacementTestView: View {
    let pack: CoursePack
    /// The lesson id to open: the recommendation, or the first lesson
    /// when the learner prefers to start from the beginning.
    var onDone: (String) -> Void
    var onSkip: () -> Void

    @State private var questions: [PlacementQuestion]
    @State private var index = 0
    @State private var picked: Int?
    @State private var correctIds: Set<UUID> = []
    @State private var finished = false

    init(pack: CoursePack, onDone: @escaping (String) -> Void, onSkip: @escaping () -> Void) {
        self.pack = pack
        self.onDone = onDone
        self.onSkip = onSkip
        _questions = State(initialValue: PlacementBuilder.build(pack: pack))
    }

    private var recommendation: PlacementRecommendation? {
        PlacementBuilder.recommend(
            pack: pack, questions: questions, correctIds: correctIds)
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            if questions.isEmpty {
                emptyState
            } else if finished, let recommendation {
                resultView(recommendation: recommendation)
            } else {
                questionView
            }
        }
    }

    // MARK: Question

    private var questionView: some View {
        let question = questions[index]
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Find your level")
                    .font(DesignTokens.text(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(index + 1) of \(questions.count)")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
            }
            .padding(.top, 64)
            Text("What does this mean?")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
            Text(question.target)
                .font(DesignTokens.display(28))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.bottom, 8)
            ForEach(question.options.indices, id: \.self) { optionIndex in
                optionButton(question: question, optionIndex: optionIndex)
            }
            Spacer()
            Button("Skip the check") { onSkip() }
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private func optionButton(question: PlacementQuestion, optionIndex: Int) -> some View {
        let isPicked = picked == optionIndex
        let isCorrect = optionIndex == question.correctIndex
        let revealed = picked != nil
        let highlight = revealed && isCorrect
        return Button {
            guard picked == nil else { return }
            picked = optionIndex
            if isCorrect { correctIds.insert(question.id) }
            // A beat to take in the answer, then move on. No timers
            // the learner controls; this is just a breath.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                advance()
            }
        } label: {
            PaperCard {
                HStack {
                    Text(question.options[optionIndex])
                        .font(DesignTokens.text(16))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Spacer()
                    if highlight {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.primary)
                    } else if revealed && isPicked {
                        Image(systemName: "circle")
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
            }
            .overlay {
                if highlight {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.primary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(revealed)
    }

    private func advance() {
        if index + 1 < questions.count {
            index += 1
            picked = nil
        } else {
            if let lesson = recommendation?.lesson {
                PlacementStore.save(packId: pack.id, lessonId: lesson.id)
            }
            finished = true
        }
    }

    // MARK: Result

    private func resultView(recommendation: PlacementRecommendation) -> some View {
        let lesson = recommendation.lesson
        return VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("All done")
                .font(DesignTokens.display(30))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(recommendation.reason)
                .font(DesignTokens.text(16))
                .foregroundStyle(DesignTokens.ink)
            Text("Here's where we'd start you — say the word and we'll open it. Or begin at the very start; it's a lovely first lesson.")
                .font(DesignTokens.text(16))
                .foregroundStyle(DesignTokens.ink)
            PaperCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SUGGESTED START")
                        .font(DesignTokens.text(11, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                    Text(lesson.title)
                        .font(DesignTokens.display(20))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(lesson.objective)
                        .font(DesignTokens.text(14))
                        .foregroundStyle(DesignTokens.muted)
                        .lineLimit(2)
                }
            }
            Spacer()
            StudioPrimaryButton(label: "Start there", disabled: false) {
                onDone(lesson.id)
            }
            HStack {
                Spacer()
                Button("Start from the beginning") {
                    onDone(pack.lessons.first?.id ?? lesson.id)
                }
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Not enough to go on")
                .font(DesignTokens.display(24))
                .foregroundStyle(DesignTokens.inkDeep)
            Text("This course doesn't have enough example phrases to build the check yet. Starting fresh is the way.")
                .font(DesignTokens.text(15))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            StudioPrimaryButton(label: "Start fresh", disabled: false) {
                onDone(pack.lessons.first?.id ?? "")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
