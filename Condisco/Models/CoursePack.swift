import Foundation

// MARK: - CoursePack
// Authored v2 course-pack models, mirroring schema-v2.ts from the web repo.
// Decode-only: packs ship as bundled JSON and are never encoded on device.

/// Discriminator key shared by every discriminated union in the pack.
private enum KindKey: String, CodingKey {
    case kind
}

struct CoursePack: Decodable {
    let schemaVersion: Int
    let id: String
    let version: String
    let language: CourseLanguage
    let status: PackStatus
    let title: String
    let sourceLanguage: String
    let description: String
    let attribution: String
    let units: [CourseUnit]
    let concepts: [CourseConcept]
    let vocabulary: [VocabularyItem]
    let media: [MediaItem]
    let stimuli: [Stimulus]
    let activities: [Activity]
    let lessons: [Lesson]
    let dialogues: [Dialogue]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, version, language, status, title,
             sourceLanguage, description, attribution, units, concepts,
             vocabulary, media, stimuli, activities, lessons, dialogues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container,
                debugDescription: "expected schemaVersion 2, got \(version)")
        }
        schemaVersion = version
        id = try container.decode(String.self, forKey: .id)
        self.version = try container.decode(String.self, forKey: .version)
        language = try container.decode(CourseLanguage.self, forKey: .language)
        status = try container.decodeIfPresent(PackStatus.self, forKey: .status) ?? .active
        title = try container.decode(String.self, forKey: .title)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        description = try container.decode(String.self, forKey: .description)
        attribution = try container.decode(String.self, forKey: .attribution)
        units = try container.decode([CourseUnit].self, forKey: .units)
        concepts = try container.decode([CourseConcept].self, forKey: .concepts)
        vocabulary = try container.decode([VocabularyItem].self, forKey: .vocabulary)
        media = try container.decode([MediaItem].self, forKey: .media)
        stimuli = try container.decodeIfPresent([Stimulus].self, forKey: .stimuli) ?? []
        activities = try container.decode([Activity].self, forKey: .activities)
        lessons = try container.decode([Lesson].self, forKey: .lessons)
        dialogues = try container.decodeIfPresent([Dialogue].self, forKey: .dialogues) ?? []
    }
}

enum CourseLanguage: String, Decodable {
    case italian = "it"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case german = "de"

    var displayName: String {
        switch self {
        case .italian: return "Italian"
        case .french: return "French"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .german: return "German"
        }
    }

    /// Matches ListenCourse.courseSlugs so the focus language re-aims Listen.
    var slug: String {
        switch self {
        case .italian: return "italian"
        case .french: return "french"
        case .spanish: return "spanish"
        case .portuguese: return "portuguese"
        case .german: return "german"
        }
    }
}

enum PackStatus: String, Decodable {
    case active
    case comingSoon = "coming-soon"
}

enum Skill: String, Decodable {
    case reading, listening, writing, speaking, grammar, vocabulary
}

enum AssistanceKind: String, Codable, Hashable {
    case hint, translation, transcript, model
}

enum StepPurpose: String, Decodable {
    case notice, predict, explain, practice, transfer, reflect
}

enum LessonFamily: String, Decodable {
    case discovery, story, conversation, listening
    case construction, scene, mission, recall
}

// MARK: - Units, concepts, vocabulary

struct CourseUnit: Decodable {
    let id: String
    let title: String
    let objective: String
}

struct ConceptExample: Decodable, Hashable {
    let target: String
    let meaning: String
    /// Optional media id for per-example pronunciation audio.
    /// Absent on older content; decode treats a missing key as nil.
    let mediaId: String?
}

struct CourseConcept: Decodable {
    let id: String
    let title: String
    let explanation: String
    let examples: [ConceptExample]
    let commonError: String
}

struct VocabularyItem: Decodable, Sendable, Identifiable, Hashable {
    enum GrammaticalGender: String, Decodable, Hashable {
        case masculine, feminine
    }

    let id: String
    let word: String
    let meaning: String
    let partOfSpeech: String
    let gender: GrammaticalGender?
    let example: String
}

// MARK: - Media

enum MediaItem: Decodable {
    case audio(id: String, url: String, sha256: String, attribution: String, transcript: String)
    case image(id: String, url: String, sha256: String, attribution: String)

    var id: String {
        switch self {
        case .audio(let id, _, _, _, _): return id
        case .image(let id, _, _, _): return id
        }
    }

    var isAudio: Bool {
        if case .audio = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let url = try container.decode(String.self, forKey: .url)
        let sha256 = try container.decode(String.self, forKey: .sha256)
        let attribution = try container.decode(String.self, forKey: .attribution)
        switch kind {
        case "audio":
            let transcript = try container.decode(String.self, forKey: .transcript)
            self = .audio(id: id, url: url, sha256: sha256,
                          attribution: attribution, transcript: transcript)
        case "image":
            self = .image(id: id, url: url, sha256: sha256, attribution: attribution)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown media kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, url, sha256, attribution, transcript
    }
}

// MARK: - Stimuli

struct DialogueTurn: Decodable {
    let speaker: String
    let text: String
    let meaning: String?
    let mediaId: String?
}

struct SceneRegion: Decodable {
    let id: String
    let label: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum Stimulus: Decodable {
    case text(id: String, body: String, translation: String?)
    case examples(id: String, pairs: [ConceptExample])
    case audio(id: String, mediaId: String)
    case dialogue(id: String, turns: [DialogueTurn])
    case scene(id: String, mediaId: String, alt: String,
               regions: [SceneRegion], textAlternative: String)

    var id: String {
        switch self {
        case .text(let id, _, _): return id
        case .examples(let id, _): return id
        case .audio(let id, _): return id
        case .dialogue(let id, _): return id
        case .scene(let id, _, _, _, _): return id
        }
    }

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        switch kind {
        case "text":
            self = .text(id: id,
                         body: try container.decode(String.self, forKey: .body),
                         translation: try container.decodeIfPresent(String.self, forKey: .translation))
        case "examples":
            self = .examples(id: id,
                             pairs: try container.decode([ConceptExample].self, forKey: .pairs))
        case "audio":
            self = .audio(id: id,
                          mediaId: try container.decode(String.self, forKey: .mediaId))
        case "dialogue":
            self = .dialogue(id: id,
                             turns: try container.decode([DialogueTurn].self, forKey: .turns))
        case "scene":
            self = .scene(id: id,
                          mediaId: try container.decode(String.self, forKey: .mediaId),
                          alt: try container.decode(String.self, forKey: .alt),
                          regions: try container.decode([SceneRegion].self, forKey: .regions),
                          textAlternative: try container.decode(String.self, forKey: .textAlternative))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown stimulus kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, body, translation, pairs, mediaId, turns, alt, regions, textAlternative
    }
}

// MARK: - Answers

enum ErrorCategory: String, Decodable {
    case wrongArticle = "wrong article"
    case wrongGender = "wrong gender"
    case wrongNumber = "wrong number"
    case wrongConjugation = "wrong conjugation"
    case wrongTense = "wrong tense"
    case wrongAuxiliary = "wrong auxiliary"
    case wrongPreposition = "wrong preposition"
    case missingWord = "missing word"
    case extraWord = "extra word"
    case wordOrderProblem = "word-order problem"
    case accentDiacriticIssue = "accent/diacritic issue"
    case incorrectAnswer = "incorrect answer"
}

struct AuthoredError: Decodable {
    let answer: String
    let category: ErrorCategory
    let explanation: String
}

struct AnswerSpec: Decodable {
    /// Accepted answers. Forgiving by default: an exercise testing spelling
    /// itself opts into strictness with `allowTypo: false`.
    let answers: [String]
    let allowTypo: Bool
    let errors: [AuthoredError]

    /// Construct from a retained v1 exercise base (legacy activity grading).
    init(answers: [String], allowTypo: Bool, errors: [AuthoredError]) {
        self.answers = answers
        self.allowTypo = allowTypo
        self.errors = errors
    }

    enum CodingKeys: String, CodingKey {
        case answers, allowTypo, errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answers = try container.decode([String].self, forKey: .answers)
        allowTypo = try container.decodeIfPresent(Bool.self, forKey: .allowTypo) ?? true
        errors = try container.decodeIfPresent([AuthoredError].self, forKey: .errors) ?? []
    }
}

// MARK: - Activities

/// Fields shared by every graded activity, decoded from the flat activity object.
struct GradedBase: Decodable {
    let revision: Int
    let conceptIds: [String]
    let vocabulary: [String]
    let skills: [Skill]
    let stimulusId: String?
    let prompt: String
    let hints: [String]
    let feedback: String
    let evidenceKey: String
    let assistanceAffectsEvidence: [AssistanceKind]

    enum CodingKeys: String, CodingKey {
        case revision, conceptIds, vocabulary, skills, stimulusId, prompt,
             hints, feedback, evidenceKey, assistanceAffectsEvidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decode(Int.self, forKey: .revision)
        conceptIds = try container.decode([String].self, forKey: .conceptIds)
        vocabulary = try container.decode([String].self, forKey: .vocabulary)
        skills = try container.decode([Skill].self, forKey: .skills)
        stimulusId = try container.decodeIfPresent(String.self, forKey: .stimulusId)
        prompt = try container.decode(String.self, forKey: .prompt)
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
        feedback = try container.decode(String.self, forKey: .feedback)
        evidenceKey = try container.decode(String.self, forKey: .evidenceKey)
        assistanceAffectsEvidence = try container.decodeIfPresent(
            [AssistanceKind].self, forKey: .assistanceAffectsEvidence) ?? []
    }
}

struct OptionItem: Decodable {
    let id: String
    let text: String
}

struct DialogueOption: Decodable {
    let id: String
    let text: String
    /// Some authored replies use the activity's shared feedback.
    let feedback: String?
}

struct MatchingPair: Decodable {
    let leftId: String
    let rightId: String
}

enum ClozeSegment: Decodable {
    case text(String)
    case blank(name: String, label: String)

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch kind {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "blank":
            self = .blank(name: try container.decode(String.self, forKey: .name),
                          label: try container.decode(String.self, forKey: .label))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown cloze segment kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case text, name, label
    }
}

struct LegacyActivity: Decodable {
    let id: String
    let base: GradedBase
    let exerciseId: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId
    }
}

struct InformationActivity: Decodable {
    let id: String
    let revision: Int
    let body: String
    let stimulusId: String?
}

struct TextActivity: Decodable {
    let id: String
    let base: GradedBase
    let answer: AnswerSpec

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        answer = try container.decode(AnswerSpec.self, forKey: .answer)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, answer
    }
}

struct SelectionActivity: Decodable {
    let id: String
    let base: GradedBase
    let options: [OptionItem]
    let acceptedIds: [String]
    let multiple: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        options = try container.decode([OptionItem].self, forKey: .options)
        acceptedIds = try container.decode([String].self, forKey: .acceptedIds)
        multiple = try container.decode(Bool.self, forKey: .multiple)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, options, acceptedIds, multiple
    }
}

struct OrderingActivity: Decodable {
    let id: String
    let base: GradedBase
    let tokens: [OptionItem]
    let acceptedOrders: [[String]]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tokens = try container.decode([OptionItem].self, forKey: .tokens)
        acceptedOrders = try container.decode([[String]].self, forKey: .acceptedOrders)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, tokens, acceptedOrders
    }
}

struct MatchingActivity: Decodable {
    let id: String
    let base: GradedBase
    let left: [OptionItem]
    let right: [OptionItem]
    let acceptedPairs: [MatchingPair]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        left = try container.decode([OptionItem].self, forKey: .left)
        right = try container.decode([OptionItem].self, forKey: .right)
        acceptedPairs = try container.decode([MatchingPair].self, forKey: .acceptedPairs)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, left, right, acceptedPairs
    }
}

struct ClozeActivity: Decodable {
    let id: String
    let base: GradedBase
    let segments: [ClozeSegment]
    let blanks: [String: AnswerSpec]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        segments = try container.decode([ClozeSegment].self, forKey: .segments)
        blanks = try container.decode([String: AnswerSpec].self, forKey: .blanks)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, segments, blanks
    }
}

struct DialogueChoiceActivity: Decodable {
    let id: String
    let base: GradedBase
    let options: [DialogueOption]
    let acceptedIds: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        options = try container.decode([DialogueOption].self, forKey: .options)
        acceptedIds = try container.decode([String].self, forKey: .acceptedIds)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, options, acceptedIds
    }
}

struct SceneSelectionActivity: Decodable {
    let id: String
    let base: GradedBase
    let stimulusId: String
    let acceptedRegionIds: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stimulusId = try container.decode(String.self, forKey: .stimulusId)
        acceptedRegionIds = try container.decode([String].self, forKey: .acceptedRegionIds)
        base = try GradedBase(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, stimulusId, acceptedRegionIds
    }
}

struct SelfCompareActivity: Decodable {
    let id: String
    let revision: Int
    let conceptIds: [String]
    let vocabulary: [String]
    let skills: [Skill]
    let stimulusId: String?
    let prompt: String
    let modelText: String
    let modelAudioId: String?
}

enum Activity: Decodable {
    case legacy(LegacyActivity)
    case information(InformationActivity)
    case text(TextActivity)
    case selection(SelectionActivity)
    case ordering(OrderingActivity)
    case matching(MatchingActivity)
    case cloze(ClozeActivity)
    case dialogueChoice(DialogueChoiceActivity)
    case sceneSelection(SceneSelectionActivity)
    case selfCompare(SelfCompareActivity)

    var id: String {
        switch self {
        case .legacy(let a): return a.id
        case .information(let a): return a.id
        case .text(let a): return a.id
        case .selection(let a): return a.id
        case .ordering(let a): return a.id
        case .matching(let a): return a.id
        case .cloze(let a): return a.id
        case .dialogueChoice(let a): return a.id
        case .sceneSelection(let a): return a.id
        case .selfCompare(let a): return a.id
        }
    }

    /// The graded base, nil for information and self-compare.
    var base: GradedBase? {
        switch self {
        case .legacy(let a): return a.base
        case .text(let a): return a.base
        case .selection(let a): return a.base
        case .ordering(let a): return a.base
        case .matching(let a): return a.base
        case .cloze(let a): return a.base
        case .dialogueChoice(let a): return a.base
        case .sceneSelection(let a): return a.base
        case .information, .selfCompare: return nil
        }
    }

    /// Evidence this activity produces when completed, nil for ungraded kinds.
    var evidenceKey: String? { base?.evidenceKey }

    /// The activity's own revision, for attempt event validation.
    var revision: Int {
        switch self {
        case .legacy(let a): return a.base.revision
        case .information(let a): return a.revision
        case .text(let a): return a.base.revision
        case .selection(let a): return a.base.revision
        case .ordering(let a): return a.base.revision
        case .matching(let a): return a.base.revision
        case .cloze(let a): return a.base.revision
        case .dialogueChoice(let a): return a.base.revision
        case .sceneSelection(let a): return a.base.revision
        case .selfCompare(let a): return a.revision
        }
    }

    /// The context stimulus this activity points at, if any.
    var stimulusId: String? {
        switch self {
        case .legacy: return nil
        case .information(let a): return a.stimulusId
        case .text(let a): return a.base.stimulusId
        case .selection(let a): return a.base.stimulusId
        case .ordering(let a): return a.base.stimulusId
        case .matching(let a): return a.base.stimulusId
        case .cloze(let a): return a.base.stimulusId
        case .dialogueChoice(let a): return a.base.stimulusId
        case .sceneSelection(let a): return a.stimulusId
        case .selfCompare(let a): return a.stimulusId
        }
    }

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        switch kind {
        case "legacy": self = .legacy(try LegacyActivity(from: decoder))
        case "information": self = .information(try InformationActivity(from: decoder))
        case "text": self = .text(try TextActivity(from: decoder))
        case "selection": self = .selection(try SelectionActivity(from: decoder))
        case "ordering": self = .ordering(try OrderingActivity(from: decoder))
        case "matching": self = .matching(try MatchingActivity(from: decoder))
        case "cloze": self = .cloze(try ClozeActivity(from: decoder))
        case "dialogue-choice": self = .dialogueChoice(try DialogueChoiceActivity(from: decoder))
        case "scene-selection": self = .sceneSelection(try SceneSelectionActivity(from: decoder))
        case "self-compare": self = .selfCompare(try SelfCompareActivity(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown activity kind \(kind)")
        }
    }
}

// MARK: - Legacy v1 exercises (retained per lesson for migration)

enum ExerciseMode: String, Decodable {
    case recognition, production, listening
}

struct LegacyExerciseBase: Decodable {
    let id: String
    let conceptId: String
    let prompt: String
    let explanation: String
    let vocabulary: [String]
    let reviewOf: [String]
    let answers: [String]
    let allowTypo: Bool
    let errors: [AuthoredError]

    enum CodingKeys: String, CodingKey {
        case id, conceptId, prompt, explanation, vocabulary, reviewOf,
             answers, allowTypo, errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conceptId = try container.decode(String.self, forKey: .conceptId)
        prompt = try container.decode(String.self, forKey: .prompt)
        explanation = try container.decode(String.self, forKey: .explanation)
        vocabulary = try container.decodeIfPresent([String].self, forKey: .vocabulary) ?? []
        reviewOf = try container.decodeIfPresent([String].self, forKey: .reviewOf) ?? []
        answers = try container.decode([String].self, forKey: .answers)
        allowTypo = try container.decodeIfPresent(Bool.self, forKey: .allowTypo) ?? true
        errors = try container.decodeIfPresent([AuthoredError].self, forKey: .errors) ?? []
    }
}

enum LegacyExercise: Decodable {
    case translate(base: LegacyExerciseBase, mode: ExerciseMode)
    case choice(base: LegacyExerciseBase, options: [String])
    case order(base: LegacyExerciseBase, tokens: [String])
    case cloze(base: LegacyExerciseBase)
    case transform(base: LegacyExerciseBase)
    case think(base: LegacyExerciseBase, thinkSeconds: Int)
    case dictation(base: LegacyExerciseBase, audioId: String)
    case reading(base: LegacyExerciseBase, passage: String, translation: String)

    var id: String {
        switch self {
        case .translate(let b, _): return b.id
        case .choice(let b, _): return b.id
        case .order(let b, _): return b.id
        case .cloze(let b): return b.id
        case .transform(let b): return b.id
        case .think(let b, _): return b.id
        case .dictation(let b, _): return b.id
        case .reading(let b, _, _): return b.id
        }
    }

    /// The shared v1 exercise fields, used for legacy activity grading.
    var base: LegacyExerciseBase {
        switch self {
        case .translate(let b, _): return b
        case .choice(let b, _): return b
        case .order(let b, _): return b
        case .cloze(let b): return b
        case .transform(let b): return b
        case .think(let b, _): return b
        case .dictation(let b, _): return b
        case .reading(let b, _, _): return b
        }
    }

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try LegacyExerciseBase(from: decoder)
        switch kind {
        case "translate":
            self = .translate(base: base,
                              mode: try container.decode(ExerciseMode.self, forKey: .mode))
        case "choice":
            self = .choice(base: base,
                           options: try container.decode([String].self, forKey: .options))
        case "order":
            self = .order(base: base,
                          tokens: try container.decode([String].self, forKey: .tokens))
        case "cloze":
            self = .cloze(base: base)
        case "transform":
            self = .transform(base: base)
        case "think":
            let seconds = try container.decodeIfPresent(Int.self, forKey: .thinkSeconds) ?? 10
            self = .think(base: base, thinkSeconds: seconds)
        case "dictation":
            self = .dictation(base: base,
                              audioId: try container.decode(String.self, forKey: .audioId))
        case "reading":
            self = .reading(base: base,
                            passage: try container.decode(String.self, forKey: .passage),
                            translation: try container.decode(String.self, forKey: .translation))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown legacy exercise kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mode, options, tokens, thinkSeconds, audioId, passage, translation
    }
}

// MARK: - Lessons

struct LessonStep: Decodable {
    let id: String
    let purpose: StepPurpose
    let activityId: String
    let required: Bool
    let nextStepId: String?
    let branches: [String: String]
    let supportActivityId: String?

    enum CodingKeys: String, CodingKey {
        case id, purpose, activityId, required, nextStepId, branches, supportActivityId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        purpose = try container.decode(StepPurpose.self, forKey: .purpose)
        activityId = try container.decode(String.self, forKey: .activityId)
        required = try container.decode(Bool.self, forKey: .required)
        nextStepId = try container.decodeIfPresent(String.self, forKey: .nextStepId)
        branches = try container.decodeIfPresent([String: String].self, forKey: .branches) ?? [:]
        supportActivityId = try container.decodeIfPresent(String.self, forKey: .supportActivityId)
    }
}

struct EvidenceTarget: Decodable {
    let evidenceKey: String
    let successes: Int
}

enum CompletionPolicy: Decodable {
    case legacySuccess(exerciseIds: [String])
    case participation
    case evidence(targets: [EvidenceTarget])

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch kind {
        case "legacy-success":
            self = .legacySuccess(exerciseIds: try container.decode([String].self, forKey: .exerciseIds))
        case "participation":
            self = .participation
        case "evidence":
            self = .evidence(targets: try container.decode([EvidenceTarget].self, forKey: .targets))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown completion policy kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case exerciseIds, targets
    }
}

enum PrerequisiteRequirement: Decodable {
    case participation
    case evidence(evidenceKey: String, successes: Int)
    case legacySuccess

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch kind {
        case "participation":
            self = .participation
        case "evidence":
            self = .evidence(evidenceKey: try container.decode(String.self, forKey: .evidenceKey),
                             successes: try container.decode(Int.self, forKey: .successes))
        case "legacy-success":
            self = .legacySuccess
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown prerequisite kind \(kind)")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case evidenceKey, successes
    }
}

struct Prerequisite: Decodable {
    let lessonId: String
    let requirement: PrerequisiteRequirement
}

struct Lesson: Decodable {
    let id: String
    let unitId: String
    let title: String
    let objective: String
    /// Authored CEFR tag carried over from v1. Always "A1" when present.
    let cefr: String?
    let culturalNote: String?
    let family: LessonFamily
    let revision: Int
    let estimatedMinutes: Int
    let entryStepId: String
    let steps: [LessonStep]
    let completionPolicy: CompletionPolicy
    let prerequisites: [Prerequisite]
    let conceptIds: [String]
    let vocabulary: [String]
    /// Legacy v1 exercises retained for migration; may be unused by the v2 sequence.
    let legacyExercises: [LegacyExercise]
    let legacyCompletionExerciseIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id, unitId, title, objective, cefr, culturalNote, family, revision,
             estimatedMinutes, entryStepId, steps, completionPolicy, prerequisites,
             conceptIds, vocabulary, legacyExercises, legacyCompletionExerciseIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        unitId = try container.decode(String.self, forKey: .unitId)
        title = try container.decode(String.self, forKey: .title)
        objective = try container.decode(String.self, forKey: .objective)
        cefr = try container.decodeIfPresent(String.self, forKey: .cefr)
        culturalNote = try container.decodeIfPresent(String.self, forKey: .culturalNote)
        family = try container.decode(LessonFamily.self, forKey: .family)
        revision = try container.decode(Int.self, forKey: .revision)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        entryStepId = try container.decode(String.self, forKey: .entryStepId)
        steps = try container.decode([LessonStep].self, forKey: .steps)
        completionPolicy = try container.decode(CompletionPolicy.self, forKey: .completionPolicy)
        prerequisites = try container.decodeIfPresent([Prerequisite].self, forKey: .prerequisites) ?? []
        conceptIds = try container.decode([String].self, forKey: .conceptIds)
        vocabulary = try container.decode([String].self, forKey: .vocabulary)
        legacyExercises = try container.decodeIfPresent([LegacyExercise].self, forKey: .legacyExercises) ?? []
        legacyCompletionExerciseIds = try container.decodeIfPresent(
            [String].self, forKey: .legacyCompletionExerciseIds)
    }
}

// MARK: - Dialogues (standalone conversation graphs)

struct DialogueChoice: Decodable {
    let text: String
    let next: String
    let feedback: String
}

struct DialogueNode: Decodable {
    let id: String
    let line: String
    let meaning: String
    let complete: Bool
    let choices: [DialogueChoice]

    enum CodingKeys: String, CodingKey {
        case id, line, meaning, complete, choices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        line = try container.decode(String.self, forKey: .line)
        meaning = try container.decode(String.self, forKey: .meaning)
        complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
        choices = try container.decodeIfPresent([DialogueChoice].self, forKey: .choices) ?? []
    }
}

struct Dialogue: Decodable {
    let id: String
    let title: String
    let prerequisite: String
    let goal: String
    let start: String
    let nodes: [DialogueNode]
}

// MARK: - Pack validation (mirrors normalize-pack.ts adaptV2 checks)

struct PackValidationError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

enum PackValidator {
    static func validate(_ pack: CoursePack) throws {
        func fail(_ message: String) throws -> Never {
            throw PackValidationError(message: "\(pack.id): \(message)")
        }

        // coming-soon packs must not ship content.
        if pack.status == .comingSoon {
            let shipped: [(String, Int)] = [
                ("unit", pack.units.count), ("concept", pack.concepts.count),
                ("vocabulary entry", pack.vocabulary.count), ("audio clip", pack.media.count),
                ("stimulus", pack.stimuli.count), ("activity", pack.activities.count),
                ("lesson", pack.lessons.count), ("dialogue", pack.dialogues.count),
            ]
            for (label, count) in shipped where count > 0 {
                try fail("coming-soon pack must not ship \(label)s")
            }
        }
        guard !pack.units.isEmpty, !pack.concepts.isEmpty, !pack.lessons.isEmpty else {
            try fail("active pack needs units, concepts and lessons")
        }

        func unique(_ values: [String], _ label: String) throws -> Set<String> {
            let set = Set(values)
            if set.count != values.count { try fail("duplicate \(label)") }
            return set
        }

        let units = try unique(pack.units.map(\.id), "unit")
        let concepts = try unique(pack.concepts.map(\.id), "concept")
        let vocabulary = try unique(pack.vocabulary.map(\.id), "vocabulary")
        let mediaIds = try unique(pack.media.map(\.id), "media")
        let stimulusIds = try unique(pack.stimuli.map(\.id), "stimulus")
        _ = try unique(pack.activities.map(\.id), "activity")
        let lessonIds = try unique(pack.lessons.map(\.id), "lesson")

        func checkConceptRefs(_ values: [String], _ context: String) throws {
            for c in values where !concepts.contains(c) {
                try fail("unknown concept \(c) in \(context)")
            }
        }
        func checkVocabRefs(_ values: [String], _ context: String) throws {
            for v in values where !vocabulary.contains(v) {
                try fail("unknown vocabulary \(v) in \(context)")
            }
        }

        let mediaById = Dictionary(uniqueKeysWithValues: pack.media.map { ($0.id, $0) })
        var usedMedia = Set<String>()
        func checkMedia(_ mediaId: String, audio: Bool, _ context: String) throws {
            guard let asset = mediaById[mediaId] else {
                try fail("unknown media \(mediaId) in \(context)")
            }
            if asset.isAudio != audio {
                try fail("media \(mediaId) in \(context) is \(asset.isAudio ? "audio" : "image"), expected \(audio ? "audio" : "image")")
            }
            usedMedia.insert(mediaId)
        }

        // Media URL hygiene (mirrors localUrl): local path, no traversal, right extension.
        for item in pack.media {
            let url: String
            switch item {
            case .audio(_, let u, _, _, _): url = u
            case .image(_, let u, _, _): url = u
            }
            let prefix = item.isAudio ? "/audio/" : "/images/"
            let extensions = item.isAudio
                ? [".mp3", ".wav", ".m4a", ".ogg"]
                : [".png", ".jpg", ".jpeg", ".svg", ".webp"]
            let lower = url.lowercased()
            guard url.hasPrefix(prefix),
                  !url.split(separator: "/").contains(".."),
                  extensions.contains(where: { lower.hasSuffix($0) })
            else { try fail("bad asset URL \(url) in media \(item.id)") }
        }

        let stimuliById = Dictionary(uniqueKeysWithValues: pack.stimuli.map { ($0.id, $0) })
        var usedStimuli = Set<String>()
        func checkStimulus(_ stimulusId: String, _ context: String) throws {
            guard stimulusIds.contains(stimulusId) else {
                try fail("unknown stimulus \(stimulusId) in \(context)")
            }
            usedStimuli.insert(stimulusId)
        }

        for stimulus in pack.stimuli {
            switch stimulus {
            case .audio(_, let mediaId):
                try checkMedia(mediaId, audio: true, "stimulus \(stimulus.id)")
            case .scene(_, let mediaId, _, let regions, _):
                try checkMedia(mediaId, audio: false, "stimulus \(stimulus.id)")
                _ = try unique(regions.map(\.id), "scene region in \(stimulus.id)")
                for r in regions {
                    guard r.x >= 0, r.y >= 0, r.width > 0, r.height > 0,
                          r.width <= 1, r.height <= 1,
                          r.x + r.width <= 1, r.y + r.height <= 1
                    else { try fail("scene region \(r.id) outside [0,1] bounds in \(stimulus.id)") }
                }
            case .dialogue(_, let turns):
                for turn in turns where turn.mediaId != nil {
                    try checkMedia(turn.mediaId!, audio: true, "stimulus \(stimulus.id)")
                }
            case .text, .examples:
                break
            }
        }

        let activitiesById = Dictionary(uniqueKeysWithValues: pack.activities.map { ($0.id, $0) })

        // Legacy exercise identities: unique globally so old progress replays.
        var legacyById = [String: LegacyExercise]()
        for lesson in pack.lessons {
            for exercise in lesson.legacyExercises {
                guard legacyById[exercise.id] == nil else {
                    try fail("duplicate legacy exercise \(exercise.id)")
                }
                legacyById[exercise.id] = exercise
                if case .dictation(_, let audioId) = exercise {
                    guard mediaIds.contains(audioId) else {
                        try fail("missing audio \(audioId) in legacy \(exercise.id)")
                    }
                    usedMedia.insert(audioId)
                }
            }
        }

        for activity in pack.activities {
            let context = "activity \(activity.id)"
            if let base = activity.base {
                try checkConceptRefs(base.conceptIds, context)
                try checkVocabRefs(base.vocabulary, context)
                if !base.assistanceAffectsEvidence.contains(.model) {
                    try fail("model reveal must affect evidence in \(context)")
                }
                if let stimulusId = base.stimulusId {
                    try checkStimulus(stimulusId, context)
                }
            } else if case .information(let info) = activity,
                      let stimulusId = info.stimulusId {
                try checkStimulus(stimulusId, context)
            } else if case .selfCompare(let sc) = activity {
                try checkConceptRefs(sc.conceptIds, context)
                try checkVocabRefs(sc.vocabulary, context)
                if let stimulusId = sc.stimulusId {
                    try checkStimulus(stimulusId, context)
                }
                if let audioId = sc.modelAudioId {
                    try checkMedia(audioId, audio: true, context)
                }
            }
            switch activity {
            case .legacy(let a):
                guard legacyById[a.exerciseId] != nil else {
                    try fail("unknown legacy exercise \(a.exerciseId) in \(context)")
                }
            case .selection(let a):
                let options = try unique(a.options.map(\.id), "selection option in \(a.id)")
                for accepted in a.acceptedIds where !options.contains(accepted) {
                    try fail("unknown accepted option \(accepted) in \(context)")
                }
                if !a.multiple, a.acceptedIds.count != 1 {
                    try fail("single-select \(context) needs exactly one accepted option")
                }
            case .ordering(let a):
                let tokens = a.tokens.map(\.id)
                _ = try unique(tokens, "ordering token in \(a.id)")
                let tokenSet = Set(tokens)
                for order in a.acceptedOrders {
                    guard order.count == tokens.count,
                          order.allSatisfy(tokenSet.contains),
                          Set(order).count == order.count
                    else { try fail("accepted order is not a permutation of tokens in \(context)") }
                }
            case .matching(let a):
                let left = try unique(a.left.map(\.id), "matching left in \(a.id)")
                let right = try unique(a.right.map(\.id), "matching right in \(a.id)")
                var seen = Set<String>()
                for pair in a.acceptedPairs {
                    guard left.contains(pair.leftId), right.contains(pair.rightId) else {
                        try fail("unknown matching pair \(pair.leftId)/\(pair.rightId) in \(context)")
                    }
                    let key = "\(pair.leftId)|\(pair.rightId)"
                    guard seen.insert(key).inserted else {
                        try fail("duplicate matching pair in \(context)")
                    }
                }
            case .cloze(let a):
                var blanks = Set<String>()
                for segment in a.segments {
                    if case .blank(let name, _) = segment {
                        guard blanks.insert(name).inserted else {
                            try fail("duplicate blank \(name) in \(context)")
                        }
                    }
                }
                let keys = Set(a.blanks.keys)
                guard blanks == keys else {
                    try fail("blank/answer mismatch in \(context)")
                }
            case .dialogueChoice(let a):
                let options = try unique(a.options.map(\.id), "dialogue option in \(a.id)")
                for accepted in a.acceptedIds where !options.contains(accepted) {
                    try fail("unknown accepted reply \(accepted) in \(context)")
                }
            case .sceneSelection(let a):
                guard case .scene(_, _, _, let regions, _) = stimuliById[a.stimulusId] else {
                    try fail("scene-selection \(context) needs a scene stimulus")
                }
                let regionIds = Set(regions.map(\.id))
                for region in a.acceptedRegionIds where !regionIds.contains(region) {
                    try fail("unknown scene region \(region) in \(context)")
                }
            case .information, .selfCompare, .text:
                break
            }
        }

        var usedActivities = Set<String>()
        for lesson in pack.lessons {
            let context = "lesson \(lesson.id)"
            let legacyCompletionIds: [String]
            if let explicit = lesson.legacyCompletionExerciseIds {
                legacyCompletionIds = explicit
            } else if case .legacySuccess(let ids) = lesson.completionPolicy {
                legacyCompletionIds = ids
            } else {
                legacyCompletionIds = []
            }
            if !lesson.legacyExercises.isEmpty, legacyCompletionIds.isEmpty {
                try fail("missing legacy completion requirements in \(context)")
            }
            _ = try unique(legacyCompletionIds, "legacy completion exercise in \(context)")
            if case .legacySuccess(let policyIds) = lesson.completionPolicy {
                let policySet = try unique(policyIds, "legacy completion policy in \(context)")
                guard policySet == Set(legacyCompletionIds) else {
                    try fail("conflicting legacy completion requirements in \(context)")
                }
            }
            let lessonExerciseIds = Set(lesson.legacyExercises.map(\.id))
            // Rewritten lessons retain historical IDs for progress migration,
            // even when they no longer ship legacy exercises. Active legacy
            // completion policies must still resolve every exercise.
            let requiresLegacyExercises: Bool
            if case .legacySuccess = lesson.completionPolicy {
                requiresLegacyExercises = true
            } else {
                requiresLegacyExercises = !lesson.legacyExercises.isEmpty
            }
            if requiresLegacyExercises {
                for exerciseId in legacyCompletionIds where !lessonExerciseIds.contains(exerciseId) {
                    try fail("unknown legacy completion exercise \(exerciseId) in \(context)")
                }
            }
            guard units.contains(lesson.unitId) else {
                try fail("unknown unit in \(context)")
            }
            try checkConceptRefs(lesson.conceptIds, context)
            try checkVocabRefs(lesson.vocabulary, context)
            for prerequisite in lesson.prerequisites {
                guard lessonIds.contains(prerequisite.lessonId) else {
                    try fail("unknown prerequisite \(prerequisite.lessonId) in \(context)")
                }
                guard prerequisite.lessonId != lesson.id else {
                    try fail("self prerequisite in \(context)")
                }
            }

            let stepsById = Dictionary(uniqueKeysWithValues: lesson.steps.map { ($0.id, $0) })
            _ = try unique(lesson.steps.map(\.id), "step in \(context)")
            guard stepsById[lesson.entryStepId] != nil else {
                try fail("unknown entry step in \(context)")
            }
            for step in lesson.steps {
                guard let activity = activitiesById[step.activityId] else {
                    try fail("unknown activity \(step.activityId) in step \(step.id)")
                }
                usedActivities.insert(step.activityId)
                if let supportId = step.supportActivityId {
                    guard activitiesById[supportId] != nil else {
                        try fail("unknown support activity in step \(step.id)")
                    }
                    usedActivities.insert(supportId)
                }
                if let next = step.nextStepId, stepsById[next] == nil {
                    try fail("unknown next step \(next) in step \(step.id)")
                }
                let branchTargets = Array(step.branches.values)
                for target in branchTargets where stepsById[target] == nil {
                    try fail("unknown branch target \(target) in step \(step.id)")
                }
                if !branchTargets.isEmpty {
                    guard case .dialogueChoice(let dc) = activity else {
                        try fail("branches only allowed on dialogue choices in step \(step.id)")
                    }
                    let options = Set(dc.options.map(\.id))
                    for key in step.branches.keys where !options.contains(key) {
                        try fail("branch \(key) is not a reply option in step \(step.id)")
                    }
                }
            }
            // Support activities rejoin their step; never path activities.
            let pathActivityIds = Set(lesson.steps.map(\.activityId))
            for step in lesson.steps {
                if let supportId = step.supportActivityId,
                   pathActivityIds.contains(supportId) {
                    try fail("support activity doubles as a path activity in step \(step.id)")
                }
            }
            // Reachability + cycle check from the entry step.
            var visited = Set<String>()
            var visiting = [String]()
            func visit(_ stepId: String) throws {
                if visiting.contains(stepId) {
                    try fail("step graph cycle at \(stepId) in \(context)")
                }
                guard !visited.contains(stepId) else { return }
                visiting.append(stepId)
                visited.insert(stepId)
                guard let step = stepsById[stepId] else {
                    try fail("unknown step \(stepId) in \(context)")
                }
                if let next = step.nextStepId { try visit(next) }
                for target in step.branches.values { try visit(target) }
                visiting.removeLast()
            }
            try visit(lesson.entryStepId)
            guard visited.count == lesson.steps.count else {
                try fail("unreachable step in \(context)")
            }
            let terminals = lesson.steps.filter {
                $0.nextStepId == nil && $0.branches.isEmpty
            }
            guard !terminals.isEmpty else {
                try fail("no terminal step in \(context)")
            }
            // Every terminal path must satisfy an evidence completion policy.
            if case .evidence(let targets) = lesson.completionPolicy {
                var paths = [[String]]()
                func walk(_ stepId: String, _ trail: [String]) throws {
                    guard paths.count < 5000 else {
                        try fail("step graph too complex in \(context)")
                    }
                    guard let step = stepsById[stepId] else {
                        try fail("unknown step \(stepId) in \(context)")
                    }
                    let next = trail + [stepId]
                    var successors = [String]()
                    if let nextId = step.nextStepId { successors.append(nextId) }
                    successors.append(contentsOf: step.branches.values)
                    guard !successors.isEmpty else {
                        paths.append(next)
                        return
                    }
                    for successor in successors {
                        guard !next.contains(successor) else {
                            try fail("step graph cycle at \(successor) in \(context)")
                        }
                        try walk(successor, next)
                    }
                }
                try walk(lesson.entryStepId, [])
                for path in paths {
                    var produced = Set<String>()
                    for stepId in path {
                        guard let step = stepsById[stepId], step.required,
                              let key = activitiesById[step.activityId]?.evidenceKey
                        else { continue }
                        produced.insert(key)
                    }
                    for target in targets where !produced.contains(target.evidenceKey) {
                        try fail("evidence \(target.evidenceKey) unreachable on a terminal path in \(context)")
                    }
                }
            }
        }

        for activity in pack.activities where !usedActivities.contains(activity.id) {
            try fail("orphaned activity \(activity.id)")
        }
        for stimulus in pack.stimuli where !usedStimuli.contains(stimulus.id) {
            try fail("orphaned stimulus \(stimulus.id)")
        }
        for id in mediaIds where !usedMedia.contains(id) {
            try fail("orphaned media \(id)")
        }

        for dialogue in pack.dialogues {
            let nodeIds = Set(dialogue.nodes.map(\.id))
            guard nodeIds.contains(dialogue.start) else {
                try fail("dialogue \(dialogue.id): unknown start node")
            }
            for node in dialogue.nodes {
                for choice in node.choices where !nodeIds.contains(choice.next) {
                    try fail("dialogue \(dialogue.id): unknown choice target \(choice.next)")
                }
            }
        }
    }
}
