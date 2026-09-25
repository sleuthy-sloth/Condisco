import Foundation

// MARK: - Answer engine
//
// Faithful port of the web app's `answer.ts`: the deterministic text engine
// underneath text, cloze-blank, and legacy activities. `credit` says how much
// of the answer the learner actually produced; `accepted` only answers "does
// this advance the lesson?" A missing accent is worth partial credit and
// acceptance, because the learner produced the right word and a typography
// layer got in the way.

enum AnswerCredit: String {
    case full, partial, none
}

struct AnswerEvaluation {
    var accepted: Bool
    var credit: AnswerCredit
    var category: String
    var explanation: String
    var model: String
    /// The form to show back when the answer was accepted with something to
    /// fix. Only set when there is a specific thing to see, so the UI can
    /// render a correction instead of a bare acknowledgement.
    var correction: String?
}

enum AnswerEngine {
    static func normalize(_ text: String) -> String {
        var result = text.precomposedStringWithCanonicalMapping
        result = result.lowercased()
        result = result.replacingOccurrences(of: "[‘’ʼ`]", with: "'", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"[¿¡!?.,;:"“”()\[\]{}]"#,
            with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*'\\s*", with: "'", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func unaccent(_ text: String) -> String {
        let decomposed = text.decomposedStringWithCanonicalMapping
        let stripped = decomposed.unicodeScalars.filter { scalar in
            let category = scalar.properties.generalCategory
            return category != .nonspacingMark
                && category != .spacingMark
                && category != .enclosingMark
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: stripped)
        return result
    }

    /// Bounded edit distance, including adjacent transposition. Never a
    /// semantic grader.
    static func distance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if abs(aChars.count - bChars.count) > 2 { return 3 }
        var rows = Array(
            repeating: Array(repeating: 0, count: bChars.count + 1),
            count: aChars.count + 1)
        for i in 0...aChars.count { rows[i][0] = i }
        for j in 0...bChars.count { rows[0][j] = j }
        if aChars.isEmpty || bChars.isEmpty {
            return rows[aChars.count][bChars.count]
        }
        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                rows[i][j] = min(
                    min(rows[i - 1][j] + 1, rows[i][j - 1] + 1),
                    rows[i - 1][j - 1] + cost
                )
                if i > 1 && j > 1 && aChars[i - 1] == bChars[j - 2] && aChars[i - 2] == bChars[j - 1] {
                    rows[i][j] = min(rows[i][j], rows[i - 2][j - 2] + 1)
                }
            }
        }
        return rows[aChars.count][bChars.count]
    }

    static func evaluate(response: String, spec: AnswerSpec) -> AnswerEvaluation {
        let input = normalize(response)
        let model = spec.answers.first ?? ""
        func result(_ category: String, _ explanation: String,
                    accepted: Bool = false, credit: AnswerCredit = .none,
                    correction: String? = nil) -> AnswerEvaluation {
            AnswerEvaluation(accepted: accepted, credit: credit, category: category,
                             explanation: explanation, model: model, correction: correction)
        }
        if input.isEmpty || input.count > 1000 {
            return result("incorrect answer",
                          "Write an answer, or study the model and try again.")
        }
        if let exact = spec.answers.firstIndex(where: { normalize($0) == input }) {
            return result(
                exact == 0 ? "correct" : "acceptable alternative",
                exact == 0 ? "That is the answer." : "That is one of the accepted forms.",
                accepted: true, credit: .full)
        }
        if let error = spec.errors.first(where: { normalize($0.answer) == input }) {
            return result(error.category.rawValue, error.explanation)
        }
        // Accept minor accent and contraction-apostrophe slips with the
        // written form shown back. But only where an accent decorates a word:
        // in Italian "e"
        // (and) and "è" (is), in French "a" (has) and "à" (to), "ou" (or)
        // and "où" (where), are different words, and forgiving those erases
        // the grammar the accent is carrying. So the rule is judged per
        // DIFFERING word and only above a length floor, which leaves short
        // words elsewhere in the sentence ("un", "a") free to stay short.
        for answer in spec.answers {
            let expected = normalize(answer)
            let inputBare = unaccent(input)
            let expectedBare = unaccent(expected)
            let apostropheDifference = inputBare != expectedBare
            guard inputBare.replacingOccurrences(of: "'", with: "")
                    == expectedBare.replacingOccurrences(of: "'", with: "")
            else { continue }
            let a = input.split(separator: " ").map(String.init)
            let b = expected.split(separator: " ").map(String.init)
            guard a.count == b.count else { continue }
            let forgiving = zip(a, b).allSatisfy { pair in
                let (word, want) = pair
                if word == want { return true }
                let bare = unaccent(word)
                if bare == unaccent(want) { return bare.count >= 4 }
                // Apostrophes in contractions are easy to omit on a phone.
                // Keep this limited to longer words and packs that allow
                // typing slips; single-letter grammar contrasts stay strict.
                return spec.allowTypo && max(bare.count, want.count) >= 3
                    && bare.replacingOccurrences(of: "'", with: "")
                        == unaccent(want).replacingOccurrences(of: "'", with: "")
            }
            guard zip(a, b).contains(where: { $0.0 != $0.1 }) else { continue }
            // The diagnostic is worth giving either way: a learner who wrote
            // "e" for "è" has an accent problem and should be told so. Only
            // the acceptance is withheld, because there the accent is the
            // whole word.
            return result(
                "accent/diacritic issue",
                forgiving
                    ? "Right words. \(apostropheDifference ? "Add the accent or apostrophe" : "Add the accent"): “\(response.trimmingCharacters(in: .whitespacesAndNewlines))” → “\(answer)”"
                    : "This accent changes the word: “\(response.trimmingCharacters(in: .whitespacesAndNewlines))” → “\(answer)”",
                accepted: forgiving, credit: forgiving ? .partial : .none,
                correction: answer)
        }
        for answer in spec.answers {
            let expected = normalize(answer)
            let a = input.split(separator: " ").map(String.init)
            let b = expected.split(separator: " ").map(String.init)
            if a.count == b.count && a.sorted().joined(separator: " ") == b.sorted().joined(separator: " ") {
                return result("word-order problem",
                              "The words are here; check their order against the model.")
            }
        }
        func isSubsequence(_ short: [String], _ long: [String]) -> Bool {
            var i = 0
            for word in long where i < short.count {
                if word == short[i] { i += 1 }
            }
            return i == short.count
        }
        for answer in spec.answers {
            let a = input.split(separator: " ").map(String.init)
            let b = normalize(answer).split(separator: " ").map(String.init)
            if a.count < b.count && isSubsequence(a, b) {
                return result("missing word",
                              "One or more words are missing. Compare the complete phrase.")
            }
            if a.count > b.count && isSubsequence(b, a) {
                return result("extra word",
                              "There are extra words. They may change the meaning. Compare the model.")
            }
        }
        for answer in spec.answers {
            let expected = normalize(answer)
            guard expected.count <= 1000 else { continue }
            let a = input.split(separator: " ").map(String.init)
            let b = expected.split(separator: " ").map(String.init)
            // Only a same-length answer with exactly one altered word can be
            // forgiven, so a dropped or reordered word is never laundered
            // into "a typo".
            guard a.count == b.count && !a.isEmpty else { continue }
            let differing = a.indices.filter { a[$0] != b[$0] }
            guard differing.count == 1, let idx = differing.first else { continue }
            let wrong = a[idx], right = b[idx]
            // Both forms need enough letters to carry meaning: forgiving a
            // one- or two-letter slip would forgive a grammar word, which
            // changes the sentence.
            guard wrong.count >= 4 && right.count >= 4 else { continue }
            let edited = distance(wrong, right)
            // A longer word earns one more edit, because "common misspelling"
            // scales with length and a single-slip rule rejects real typos in
            // long words.
            let allowed = wrong.count >= 8 && right.count >= 8 ? 2 : 1
            if edited <= allowed {
                if spec.allowTypo {
                    return result(
                        "correct with typo",
                        "Meaning accepted. Check the spelling: “\(wrong)” → “\(right)”.",
                        accepted: true, credit: .partial, correction: answer)
                }
                return result(
                    "nearly correct",
                    "A small spelling or grammar difference remains. Compare the model.")
            }
        }
        return result(
            "incorrect answer",
            "That is not the form we are looking for. Study the explanation, then try again.")
    }
}
