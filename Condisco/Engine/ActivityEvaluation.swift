import Foundation

// MARK: - Activity evaluation
//
// Faithful port of the web app's `activity-evaluation.ts`: deterministic typed
// evaluation. Pure function — no storage, clocks, or randomness.
// `AnswerEngine` stays the text engine underneath text, cloze-blank, and
// legacy activities.

enum ActivityEvaluation {
    private static func sameSet(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        return a.sorted() == b.sorted()
    }

    private static func samePairs(_ a: [ResponsePair], _ b: [MatchingPair]) -> Bool {
        guard a.count == b.count else { return false }
        let keyA = a.map { "\($0.leftId)|\($0.rightId)" }.sorted()
        let keyB = b.map { "\($0.leftId)|\($0.rightId)" }.sorted()
        return keyA == keyB
    }

    private static func mismatch(_ activityId: String) -> AttemptEvaluation {
        AttemptEvaluation(outcome: .incorrect, independent: false,
                          feedback: "Response does not fit activity \(activityId). Try again.")
    }

    /// Evaluate a learner response against an activity. `legacyExercises` is
    /// the current lesson's retained v1 exercise collection, used only for
    /// legacy activities.
    static func evaluate(activity: Activity,
                         response: AttemptResponse,
                         assistance: [AssistanceKind],
                         legacyExercises: [LegacyExercise] = []) -> AttemptEvaluation {
        let taintKinds = activity.base?.assistanceAffectsEvidence ?? []
        let tainted = assistance.contains(.model)
            || assistance.contains(where: { taintKinds.contains($0) })
        let independent = !tainted
        func retry(_ feedback: String) -> AttemptEvaluation {
            AttemptEvaluation(outcome: .incorrect, independent: false, feedback: feedback)
        }

        switch activity {
        case .information:
            if case .continue = response {
                return AttemptEvaluation(outcome: .ungraded, independent: false, feedback: "")
            }
            return mismatch(activity.id)

        case .selfCompare(let spec):
            if case .selfRating = response {
                return AttemptEvaluation(outcome: .selfAssessed, independent: false,
                                         feedback: spec.modelText)
            }
            return mismatch(activity.id)

        case .text(let spec):
            guard case .text(let text) = response else { return mismatch(activity.id) }
            let judged = AnswerEngine.evaluate(response: text, spec: spec.answer)
            return judged.accepted
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: judged.correction == nil ? spec.base.feedback : judged.explanation,
                                    correction: judged.correction)
                : AttemptEvaluation(outcome: .incorrect, independent: false,
                                    feedback: judged.explanation, correction: judged.model)

        case .legacy(let spec):
            guard case .text(let text) = response else { return mismatch(activity.id) }
            guard let exercise = legacyExercises.first(where: { $0.id == spec.exerciseId }) else {
                return mismatch(activity.id)
            }
            let answerSpec = AnswerSpec(answers: exercise.base.answers,
                                        allowTypo: exercise.base.allowTypo,
                                        errors: exercise.base.errors)
            let judged = AnswerEngine.evaluate(response: text, spec: answerSpec)
            return judged.accepted
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: judged.correction == nil ? spec.base.feedback : judged.explanation,
                                    correction: judged.correction)
                : AttemptEvaluation(outcome: .incorrect, independent: false,
                                    feedback: judged.explanation, correction: judged.model)

        case .selection(let spec):
            guard case .selection(let ids) = response else { return mismatch(activity.id) }
            let options = Set(spec.options.map { $0.id })
            if ids.contains(where: { !options.contains($0) })
                || Set(ids).count != ids.count
                || (!spec.multiple && ids.count != 1) {
                return retry(spec.base.hints.first ?? "That selection is not valid. Try again.")
            }
            return sameSet(ids, spec.acceptedIds)
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: spec.base.feedback)
                : retry(spec.base.hints.first ?? "Not quite — try again.")

        case .dialogueChoice(let spec):
            guard case .selection(let ids) = response else { return mismatch(activity.id) }
            guard ids.count == 1, let chosen = spec.options.first(where: { $0.id == ids[0] }) else {
                return retry("Choose one of the authored replies.")
            }
            return spec.acceptedIds.contains(chosen.id)
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: chosen.feedback ?? spec.base.feedback)
                : AttemptEvaluation(outcome: .incorrect, independent: false,
                                    feedback: chosen.feedback ?? spec.base.feedback)

        case .sceneSelection(let spec):
            guard case .selection(let ids) = response else { return mismatch(activity.id) }
            if Set(ids).count != ids.count {
                return retry("Each region counts once. Try again.")
            }
            return sameSet(ids, spec.acceptedRegionIds)
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: spec.base.feedback)
                : retry(spec.base.hints.first ?? "Not quite — try again.")

        case .ordering(let spec):
            guard case .ordering(let ids) = response else { return mismatch(activity.id) }
            let tokens = spec.tokens.map { $0.id }
            if !sameSet(ids, tokens) {
                return retry("Place every token exactly once.")
            }
            let accepted = spec.acceptedOrders.contains(where: { order in
                order.count == ids.count && zip(order, ids).allSatisfy { $0.0 == $0.1 }
            })
            return accepted
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: spec.base.feedback)
                : retry(spec.base.hints.first ?? "The order is not right yet. Try again.")

        case .matching(let spec):
            guard case .matching(let pairs) = response else { return mismatch(activity.id) }
            let left = Set(spec.left.map { $0.id })
            let right = Set(spec.right.map { $0.id })
            let pairKeys = pairs.map { "\($0.leftId)|\($0.rightId)" }
            if pairs.contains(where: { !left.contains($0.leftId) || !right.contains($0.rightId) })
                || Set(pairKeys).count != pairKeys.count {
                return retry("Each pairing must use listed items exactly once.")
            }
            return samePairs(pairs, spec.acceptedPairs)
                ? AttemptEvaluation(outcome: .correct, independent: independent,
                                    feedback: spec.base.feedback)
                : retry(spec.base.hints.first ?? "Some pairs are off. Try again.")

        case .cloze(let spec):
            guard case .cloze(let values) = response else { return mismatch(activity.id) }
            // Sorted for determinism: when several blanks fail, the first
            // alphabetically reports. (The web uses JSON insertion order.)
            var corrections: [String] = []
            for name in spec.blanks.keys.sorted() {
                let blankSpec = spec.blanks[name]!
                let judged = AnswerEngine.evaluate(response: values[name] ?? "", spec: blankSpec)
                if !judged.accepted {
                    return AttemptEvaluation(outcome: .incorrect, independent: false,
                                             feedback: judged.explanation,
                                             correction: judged.model)
                }
                if let correction = judged.correction {
                    corrections.append(correction)
                }
            }
            return AttemptEvaluation(outcome: .correct, independent: independent,
                                     feedback: corrections.isEmpty
                                         ? spec.base.feedback : "Accepted. Notice the spelling below.",
                                     correction: corrections.isEmpty
                                         ? nil : corrections.joined(separator: " · "))
        }
    }
}

// MARK: - Player helpers (ported from LessonPlayer.tsx)

/// Whether a draft response is complete enough to enable the Check button.
func validDraft(_ response: AttemptResponse?) -> Bool {
    guard let response else { return false }
    switch response {
    case .text(let text):
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .selection(let ids), .ordering(let ids):
        return !ids.isEmpty
    case .matching(let pairs):
        return !pairs.isEmpty
    case .cloze(let values):
        return values.values.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    case .selfRating, .continue:
        return true
    }
}

func outcomeWord(_ outcome: AttemptEvaluation.Outcome) -> String {
    switch outcome {
    case .correct: return "That's it."
    case .incorrect: return "Not quite — try again."
    case .selfAssessed: return "Compare with the model — this one isn't graded."
    case .blocked: return "Not saved — check your connection and try again."
    case .ungraded: return "Not graded — continue when you're ready."
    }
}

/// Short hint string for the current practice step. For cloze steps, the
/// first letter of the first accepted answer; otherwise a generic prompt.
func hintText(for activity: Activity) -> String {
    if case .cloze(let spec) = activity,
       let firstBlank = spec.blanks.keys.sorted().first,
       let firstAnswer = spec.blanks[firstBlank]?.answers.first,
       let firstLetter = firstAnswer.first {
        return String(firstLetter).uppercased()
    }
    return "Try it"
}
