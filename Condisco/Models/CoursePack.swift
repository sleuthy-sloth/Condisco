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
    let checkpoints: [CheckpointTask]
    let dialogues: [Dialogue]
    /// Phase 6.1A sustained reading passages (first-class lesson material).
    /// Additive shape: packs written before 6.1 simply carry no
    /// `sustainedTexts` key and decode with an empty array, byte-identical
    /// to their old self (see `testPackWithoutSustainedFieldsStillLoadsUnchanged`).
    let sustainedTexts: [SustainedText]
    /// Phase 6.1A sustained listening passages (first-class lesson material).
    /// Same additive rule as `sustainedTexts`.
    let sustainedListenings: [SustainedListening]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, version, language, status, title,
             sourceLanguage, description, attribution, units, concepts,
             vocabulary, media, stimuli, activities, lessons, checkpoints,
             dialogues, sustainedTexts, sustainedListenings
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
        // Additive, schema-v2 shape: packs written before the 5.3 task bank
        // simply carry no `checkpoints` key and decode with an empty bank.
        checkpoints = try container.decodeIfPresent(
            [CheckpointTask].self, forKey: .checkpoints) ?? []
        dialogues = try container.decodeIfPresent([Dialogue].self, forKey: .dialogues) ?? []
        sustainedTexts = try container.decodeIfPresent(
            [SustainedText].self, forKey: .sustainedTexts) ?? []
        sustainedListenings = try container.decodeIfPresent(
            [SustainedListening].self, forKey: .sustainedListenings) ?? []
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

// MARK: - Open tasks (Phase 6.2)
//
// A connected production task: a short written answer or a 60–90-second
// spoken response. The task carries a communicative goal, the concrete
// points the response should cover, an example (model) response, and a
// transparent learner-facing self-check rubric. NEVER auto-graded: the
// learner reveals the model, ticks the rubric against their own response,
// and the judgement is explicitly their own self-assessment. The length
// guidance ("a few connected sentences", "60–90 seconds") is a pilot
// design target shown as guidance — never a timer-enforced fail and never
// a word-count pass/fail.

/// The modality of an open task.
enum OpenTaskMode: String, Codable, Hashable {
    case written
    case spoken
}

/// One learner-facing self-check criterion (2-4 per task in 5.3; the
/// 6.2 rubric ships the four dimensions and the validator allows 3-6).
struct OpenTaskRubricCriterion: Decodable, Hashable, Identifiable {
    let id: String
    let text: String
}

struct OpenTaskActivity: Decodable {
    let id: String
    let revision: Int
    let conceptIds: [String]
    let vocabulary: [String]
    let skills: [Skill]
    let stimulusId: String?
    /// Written or spoken.
    let mode: OpenTaskMode
    /// The communicative goal — the learner-facing prompt.
    let goal: String
    /// The concrete points the response should cover.
    let requiredPoints: [String]
    /// An example response, revealed only on an explicit action (a reveal
    /// makes the attempt non-independent).
    let modelResponse: String
    /// The self-check rubric the learner ticks against their own response:
    /// meaning, organization, useful language, repair-after-a-mistake.
    let rubric: [OpenTaskRubricCriterion]
    /// Optional hints; revealing one counts as assistance like any other.
    let hints: [String]
    /// Optional length guidance ("a few connected sentences",
    /// "60–90 seconds of speaking"). Guidance only — never enforced.
    let lengthGuidance: String?

    enum CodingKeys: String, CodingKey {
        case id, revision, conceptIds, vocabulary, skills, stimulusId, mode,
             goal, requiredPoints, modelResponse, rubric, hints, lengthGuidance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        revision = try container.decode(Int.self, forKey: .revision)
        conceptIds = try container.decode([String].self, forKey: .conceptIds)
        vocabulary = try container.decode([String].self, forKey: .vocabulary)
        skills = try container.decode([Skill].self, forKey: .skills)
        stimulusId = try container.decodeIfPresent(String.self, forKey: .stimulusId)
        mode = try container.decode(OpenTaskMode.self, forKey: .mode)
        goal = try container.decode(String.self, forKey: .goal)
        requiredPoints = try container.decode([String].self, forKey: .requiredPoints)
        modelResponse = try container.decode(String.self, forKey: .modelResponse)
        rubric = try container.decode([OpenTaskRubricCriterion].self, forKey: .rubric)
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
        lengthGuidance = try container.decodeIfPresent(String.self, forKey: .lengthGuidance)
    }
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
    case openTask(OpenTaskActivity)

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
        case .openTask(let a): return a.id
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
        case .information, .selfCompare, .openTask: return nil
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
        case .openTask(let a): return a.revision
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
        case .openTask(let a): return a.stimulusId
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
        case "open-task": self = .openTask(try OpenTaskActivity(from: decoder))
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
    /// Phase 6.1A sustained-material bindings (additive, both optional): a
    /// step may present a sustained reading passage (`sustainedTextId`) or a
    /// sustained listening passage (`sustainedListeningId`) alongside its
    /// regular activity — at most one of the two. Old packs omit both keys
    /// and decode unchanged. The step's `activityId` still drives completion
    /// (typically an information step that launches the material); the view
    /// lane (6.1B) renders the material itself.
    let sustainedTextId: String?
    let sustainedListeningId: String?

    enum CodingKeys: String, CodingKey {
        case id, purpose, activityId, required, nextStepId, branches, supportActivityId,
             sustainedTextId, sustainedListeningId
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
        sustainedTextId = try container.decodeIfPresent(String.self, forKey: .sustainedTextId)
        sustainedListeningId = try container.decodeIfPresent(String.self, forKey: .sustainedListeningId)
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
    /// Stable option id for hosted exchanges: recorded in the turn event
    /// and resolved for the recap (like a step's branch id). Additive —
    /// pre-6.3 dialogues (never presented) carry no ids and decode
    /// unchanged; `PackValidator` requires ids on hosted-exchange choices.
    let id: String?
    let text: String
    let next: String
    let feedback: String

    enum CodingKeys: String, CodingKey {
        case id, text, next, feedback
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        next = try container.decode(String.self, forKey: .next)
        feedback = try container.decode(String.self, forKey: .feedback)
    }
}

/// The role a node plays in a Phase 6.3 branching exchange. Plain nodes
/// (nil) are ordinary turns in the thread; the three tagged kinds let the
/// validator and the tests prove every hosted exchange teaches asking for
/// clarification and repairing a misunderstanding. A `misunderstanding` node
/// is where the partner mishears/misreads the learner; a `recovery` node is
/// the repair route back onto the main thread; a `clarification` node is
/// where the learner asks the partner to repeat or confirm.
enum DialogueNodeKind: String, Decodable {
    case clarification
    case misunderstanding
    case recovery
}

/// One node of an exchange graph. A node is one of:
///   - a deterministic turn: the partner's `line`, and the learner replies
///     by picking one of `choices` (each choice carries the next node);
///   - an open turn (Phase 6.3): the partner's `line`, and the learner
///     COMPOSES a reply against `prompt` + `modelResponse` + a self-check
///     `rubric` (the 6.2 rubric machinery, never auto-graded) and the
///     neighbour follows through `next`;
///   - an end state: `complete == true` with no choices/prompt/next.
/// All fields but `id`, `line`, `meaning`, `complete` are additive
/// (decodeIfPresent), so packs written before 6.3 decode unchanged.
struct DialogueNode: Decodable {
    let id: String
    /// The counterpart's line the learner must interpret before replying.
    let line: String
    /// English gloss of `line`, shown under it.
    let meaning: String
    /// Tag for validator/test enforcement (clarification / misunderstanding /
    /// recovery); nil on ordinary turns.
    let kind: DialogueNodeKind?
    /// True = explicit end state of the exchange; terminal node.
    let complete: Bool
    /// Deterministic learner replies (choice turn). Mutually exclusive with
    /// the open-turn fields.
    let choices: [DialogueChoice]
    /// Open turn: the instruction for what to compose (learner-facing).
    let prompt: String?
    /// Open turn: an example reply, revealed only on an explicit action (a
    /// reveal marks the turn non-independent, exactly like 6.2 open tasks).
    let modelResponse: String?
    /// Open turn: the self-check rubric the learner ticks (3-6 criteria,
    /// reusing the 6.2 `OpenTaskRubricCriterion` shape and checks).
    let rubric: [OpenTaskRubricCriterion]?
    /// Open turn: optional soft length guidance — guidance, never enforced.
    let lengthGuidance: String?
    /// Open turn only: the node that follows the composed reply.
    let next: String?

    enum CodingKeys: String, CodingKey {
        case id, line, meaning, kind, complete, choices, prompt,
             modelResponse, rubric, lengthGuidance, next
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        line = try container.decode(String.self, forKey: .line)
        meaning = try container.decode(String.self, forKey: .meaning)
        kind = try container.decodeIfPresent(DialogueNodeKind.self, forKey: .kind)
        complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
        choices = try container.decodeIfPresent([DialogueChoice].self, forKey: .choices) ?? []
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        modelResponse = try container.decodeIfPresent(String.self, forKey: .modelResponse)
        rubric = try container.decodeIfPresent(
            [OpenTaskRubricCriterion].self, forKey: .rubric)
        lengthGuidance = try container.decodeIfPresent(String.self, forKey: .lengthGuidance)
        next = try container.decodeIfPresent(String.self, forKey: .next)
    }
}

struct Dialogue: Decodable {
    let id: String
    let title: String
    /// The lesson that gates this exchange (checked by check_packs:
    /// `prerequisite` must name a lesson in the pack).
    let prerequisite: String
    let goal: String
    /// Display name of the learner's counterpart ("Waiter", "Friend").
    /// Additive: absent on pre-6.3 dialogues (the player defaults to
    /// "Partner").
    let partner: String?
    /// Phase 6.3 hosted-exchange binding: the lesson that presents this
    /// exchange for practice after its trail completes. Additive — French /
    /// Italian dialogues predate 6.3 and stay validated-only. At most one
    /// dialogue per host lesson (PackValidator).
    let hostLessonId: String?
    let start: String
    let nodes: [DialogueNode]

    enum CodingKeys: String, CodingKey {
        case id, title, prerequisite, goal, partner, hostLessonId, start, nodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        prerequisite = try container.decode(String.self, forKey: .prerequisite)
        goal = try container.decode(String.self, forKey: .goal)
        partner = try container.decodeIfPresent(String.self, forKey: .partner)
        hostLessonId = try container.decodeIfPresent(String.self, forKey: .hostLessonId)
        start = try container.decode(String.self, forKey: .start)
        nodes = try container.decode([DialogueNode].self, forKey: .nodes)
    }
}

// MARK: - Checkpoint tasks (5.3A task bank)
//
// A checkpoint task rounds off a pathway stage: it offers unseen scenarios
// and wording drawn from this authored bank only — a checkpoint item is
// NEVER wired into a lesson step, so lesson content can never leak the
// checkpoint's passages, questions, or self-assessment rubrics. The bank is
// an additive schema-v2 shape: packs without a `checkpoints` key decode
// with an empty bank (old five-pack JSON is untouched).

/// Which pathway stage a checkpoint gates. `foundation` rounds off the
/// Foundation path (A1/untagged lessons), `developing` the Developing path
/// (A2 lessons); `independent` is declared for future content and has no
/// shipped tasks today.
enum CheckpointStage: String, Codable, Equatable {
    case foundation, developing, independent
}

/// The modality coverage a checkpoint declares. A task's `modalities` list
/// must cover every modality its items actually exercise (PackValidator).
/// `listening` is a valid slot, but the Spanish tasks omit it: the only
/// truly bundled Spanish audio (the introductions Listen track and the café
/// pilot) belongs to *lesson* steps — not unseen material — so a checkpoint
/// listening item could not bind honestly to bundled audio without shipping
/// a new recording. Listening comprehension is deferred until reviewed
/// unseen audio exists; nothing is fabricated here.
enum CheckpointModality: String, Codable, Hashable {
    case reading, listening, writing, speaking
}

/// One concrete self-assessment criterion a learner ticks after recording a
/// spoken response (2-4 per item).
struct CheckpointRubricCriterion: Decodable {
    let id: String
    let text: String
}

/// A single comprehension question over a checkpoint's passage. Auto-graded
/// recognition (fixed accepted options); free production never is.
struct CheckpointReadingQuestion: Decodable {
    let id: String
    let question: String
    let options: [OptionItem]
    let acceptedIds: [String]
}

/// An unseen reading-comprehension item: a fresh passage plus questions.
struct CheckpointReadingItem: Decodable {
    let id: String
    let passage: String
    let translation: String
    let questions: [CheckpointReadingQuestion]
}

/// A connected written response. Completes on submission and is recorded as
/// practice evidence: it carries no fixed answers and is never auto-graded
/// (strict-answer discipline, 2.2 worklist).
struct CheckpointWritingItem: Decodable {
    let id: String
    let prompt: String
}

/// A spoken response the learner records and self-assesses against a short
/// rubric (2-4 concrete criteria to tick).
struct CheckpointSpeakingItem: Decodable {
    let id: String
    let prompt: String
    let rubric: [CheckpointRubricCriterion]
}

enum CheckpointItem: Decodable {
    case reading(CheckpointReadingItem)
    case writing(CheckpointWritingItem)
    case speaking(CheckpointSpeakingItem)

    var id: String {
        switch self {
        case .reading(let item): return item.id
        case .writing(let item): return item.id
        case .speaking(let item): return item.id
        }
    }

    var modality: CheckpointModality {
        switch self {
        case .reading: return .reading
        case .writing: return .writing
        case .speaking: return .speaking
        }
    }

    init(from decoder: Decoder) throws {
        let kindContainer = try decoder.container(keyedBy: KindKey.self)
        let kind = try kindContainer.decode(String.self, forKey: .kind)
        switch kind {
        case "reading": self = .reading(try CheckpointReadingItem(from: decoder))
        case "writing": self = .writing(try CheckpointWritingItem(from: decoder))
        case "speaking": self = .speaking(try CheckpointSpeakingItem(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: kindContainer,
                debugDescription: "unknown checkpoint item kind \(kind)")
        }
    }
}

struct CheckpointTask: Decodable {
    /// Stable task id, unique across the pack (e.g. "es-cp-foundation").
    let id: String
    /// Which pathway stage this checkpoint gates (stage-end).
    let stage: CheckpointStage
    /// Modality coverage this task declares; must cover the modalities its
    /// items actually exercise (PackValidator).
    let modalities: [CheckpointModality]
    /// Learner-facing title.
    let title: String
    /// Short instructions shown before the task begins.
    let introduction: String
    let items: [CheckpointItem]
}

// MARK: - Sustained reading & listening (Phase 6.1A)
//
// First-class lesson material for multi-paragraph reading and multi-minute
// listening, authored as ORIGINAL texts for this app (never external,
// copyrighted material — every piece carries a provenance statement saying
// so). Both shapes decode additively: packs without the new top-level keys
// decode byte-identically to their old selves (same `decodeIfPresent ?? []`
// contract as `checkpoints`). A lesson step references one of these through
// `LessonStep.sustainedTextId` / `sustainedListeningId`, so the material
// stays a normal, reachable part of the lesson graph without any change to
// the activity or stimulus machinery.
//
// Comprehension questions are embedded in the material (not synthetic
// activities) and carry a `kind` — main idea, key detail, speaker intent.
// They are fixed-answer/selection style (options + acceptedIds, graded the
// same deterministic way checkpoint reading questions are): NO open
// auto-grading.

/// The three comprehension targets an embedded sustained-material question
/// asks for. Exactly one question of each kind ships per passage.
enum SustainedQuestionKind: String, Decodable, CaseIterable {
    case mainIdea = "main-idea"
    case keyDetail = "key-detail"
    case speakerIntent = "speaker-intent"

    var displayName: String {
        switch self {
        case .mainIdea: return "Main idea"
        case .keyDetail: return "Key detail"
        case .speakerIntent: return "Speaker intent"
        }
    }
}

/// The three genres the Phase 6.1A pilot path authors: arranging plans in a
/// message thread, a town-life short article, and a personal narrative.
enum SustainedGenre: String, Decodable, CaseIterable {
    case messageThread = "message-thread"
    case shortArticle = "short-article"
    case personalNarrative = "personal-narrative"
}

/// One glossary entry for a sustained passage: a term with a plain
/// definition and an optional usage note. Terms are unique per passage.
struct SustainedGlossaryEntry: Decodable {
    let term: String
    let definition: String
    let usageNote: String?
}

/// One embedded comprehension question over a sustained passage. Selection
/// style, mirroring `CheckpointReadingQuestion`: unique options, non-empty
/// `acceptedIds` that name options, deterministic set-equality grading.
struct SustainedQuestion: Decodable {
    let id: String
    let kind: SustainedQuestionKind
    let question: String
    let options: [OptionItem]
    let acceptedIds: [String]
}

/// Provenance of a sustained passage. These are ORIGINAL texts written for
/// this app, so the statement says so; no external copyrighted material.
struct SustainedProvenance: Decodable {
    let statement: String
    let date: String
}

/// One section of a sustained reading passage: a section marker, a heading,
/// one or more paragraphs, and an accessibility label VoiceOver reads when
/// entering the section. Markers are ordered and unique within a passage.
struct SustainedReadingSection: Decodable {
    let marker: String
    let heading: String
    let body: String
    let accessibilityLabel: String
}

/// A sustained reading passage: multi-paragraph original text, sectioned so
/// long content never clips or repeatedly re-presents the whole passage.
struct SustainedText: Decodable, Identifiable {
    let id: String
    let title: String
    let genre: SustainedGenre
    let sections: [SustainedReadingSection]
    /// One VoiceOver-readable summary of the whole passage (the section-list
    /// accessible label) so a screen-reader user can orient before swiping
    /// through sections.
    let accessibleSummary: String
    let glossary: [SustainedGlossaryEntry]
    let provenance: SustainedProvenance
    let questions: [SustainedQuestion]
}

/// One section of a sustained listening passage: its own text-to-synthesise
/// (so replay-per-section and slow speed are possible at the data level),
/// the section marker/heading, and the accessibility label.
struct SustainedListeningSection: Decodable {
    let marker: String
    let heading: String
    /// The full section text, rendered by on-device speech synthesis.
    let text: String
    /// Declared device voice identifier (e.g.
    /// "com.apple.voice.compact.es-ES.Monica"), used as the preferred voice
    /// for this section. This is a *preference, never a requirement*: the
    /// offline fallback rule is that when the exact identifier is not
    /// installed on the learner's device, the section is spoken by any
    /// installed voice whose language matches `languageCode` — a missing
    /// voice must never make a section unspeakable (the renderer resolves
    /// voice → fallback voice → system voice for the language, exactly like
    /// ShadowSpeaker does today). More than one voice id across the sections
    /// of a passage gives the learner two distinct synthesised voices.
    let voiceId: String
    /// The BCP-47 language tag for the declared voice (e.g. "es-ES"). The
    /// voice id must carry this tag, and it must share the pack's language
    /// root ("es" for the Spanish pack).
    let languageCode: String
    /// VoiceOver label for the section; must label the voice as synthesised
    /// ("…spoken by a synthesised Spanish (Mexico) voice").
    let accessibilityLabel: String
}

/// A sustained listening passage: multi-minute material built from ordered
/// sections, each with its own text to synthesise and voice id (two or more
/// distinct voices across the passage), plus the full transcript, a
/// glossary, provenance, and the three comprehension question kinds.
struct SustainedListening: Decodable, Identifiable {
    let id: String
    let title: String
    let sections: [SustainedListeningSection]
    /// The full text of the passage. Must equal the section texts joined in
    /// order (whitespace-insensitive), so the transcript is exactly what was
    /// spoken — never a paraphrase added later.
    let transcript: String
    let accessibleSummary: String
    let glossary: [SustainedGlossaryEntry]
    let provenance: SustainedProvenance
    let questions: [SustainedQuestion]
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
                ("lesson", pack.lessons.count), ("checkpoint", pack.checkpoints.count),
                ("dialogue", pack.dialogues.count),
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
            } else if case .openTask(let ot) = activity {
                // Phase 6.2 open task well-formedness. Open responses are
                // NEVER auto-graded, so there is no answer/acceptance shape
                // to check — the authored contract is the goal, the points,
                // the model, and the self-check rubric.
                try checkConceptRefs(ot.conceptIds, context)
                try checkVocabRefs(ot.vocabulary, context)
                if let stimulusId = ot.stimulusId {
                    try checkStimulus(stimulusId, context)
                }
                guard !ot.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("open task \(context) has no goal (communicative goal is required)")
                }
                guard !ot.requiredPoints.isEmpty else {
                    try fail("open task \(context) has no required points")
                }
                for point in ot.requiredPoints
                where point.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try fail("open task \(context) has an empty required point")
                }
                guard !ot.modelResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("open task \(context) has no model response")
                }
                guard (3...6).contains(ot.rubric.count) else {
                    try fail("open task \(context) needs a 3-6 criterion self-check rubric, got \(ot.rubric.count)")
                }
                _ = try unique(ot.rubric.map(\.id), "rubric criterion in \(context)")
                for criterion in ot.rubric
                where criterion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try fail("open task \(context) rubric criterion \(criterion.id) has no text")
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
            case .information, .selfCompare, .text, .openTask:
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

        // ---- Phase 6.3: branching-exchange graphs ----
        // The `dialogues` array ships conversation graphs. Pre-6.3 packs
        // (French/Italian) decode unchanged and pass the base structural
        // checks; hosted exchanges (`hostLessonId` present) additionally
        // must teach asking-for-clarification and repairing a
        // misunderstanding, keep every branch finite with an explicit end
        // state, and satisfy linear depth >= 3 turns on every path.
        _ = try unique(pack.dialogues.map(\.id), "dialogue")
        var dialogueHosts = [String: String]()
        for dialogue in pack.dialogues {
            let context = "dialogue \(dialogue.id)"
            let nodesById = Dictionary(uniqueKeysWithValues: dialogue.nodes.map { ($0.id, $0) })
            _ = try unique(dialogue.nodes.map(\.id), "node in \(context)")
            guard nodesById[dialogue.start] != nil else {
                try fail("\(context): unknown start node \(dialogue.start)")
            }
            if let host = dialogue.hostLessonId {
                guard lessonIds.contains(host) else {
                    try fail("\(context): host lesson \(host) is not a lesson in this pack")
                }
                if let previous = dialogueHosts[host] {
                    try fail("a lesson hosts one dialogue each: \(host) hosts both \(previous) and \(dialogue.id)")
                }
                dialogueHosts[host] = dialogue.id
            }
            for node in dialogue.nodes {
                let nodeContext = "\(context) node \(node.id)"
                if node.complete {
                    guard node.choices.isEmpty, node.prompt == nil, node.next == nil else {
                        try fail("\(nodeContext): a complete end state must be terminal (no choices, prompt or next)")
                    }
                    guard node.kind == nil else {
                        try fail("\(nodeContext): a complete end state cannot carry a clarification/misunderstanding/recovery tag")
                    }
                    continue
                }
                // Every non-end node is a turn: deterministic choices XOR an
                // open prompt — never both, never neither (a neither would be
                // a dead end with no way forward).
                let hasChoices = !node.choices.isEmpty
                let hasPrompt = node.prompt != nil
                guard hasChoices != hasPrompt else {
                    try fail("\(nodeContext): a turn must offer either choices or an open prompt — got \(hasChoices ? "both" : "neither")")
                }
                if hasChoices {
                    _ = try unique(node.choices.map(\.text), "choice in \(nodeContext)")
                    guard node.next == nil else {
                        try fail("\(nodeContext): a choice turn carries no next node (the choices route)")
                    }
                    guard node.modelResponse == nil, node.rubric == nil else {
                        try fail("\(nodeContext): a choice turn cannot also carry open-turn fields")
                    }
                    for choice in node.choices where nodesById[choice.next] == nil {
                        try fail("\(nodeContext): unknown choice target \(choice.next)")
                    }
                    if dialogue.hostLessonId != nil {
                        let ids = node.choices.map { $0.id ?? "" }
                        guard !ids.contains(""), Set(ids).count == ids.count else {
                            try fail("\(nodeContext): hosted-exchange choices need unique non-empty ids")
                        }
                    }
                } else {
                    guard let next = node.next, nodesById[next] != nil else {
                        try fail("\(nodeContext): an open turn needs a resolvable next node")
                    }
                    guard !(node.prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        try fail("\(nodeContext): an open turn needs a prompt")
                    }
                    guard !(node.modelResponse ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        try fail("\(nodeContext): an open turn needs a model response")
                    }
                    let rubric = node.rubric ?? []
                    guard (3...6).contains(rubric.count) else {
                        try fail("\(nodeContext): open turn needs a 3-6 criterion self-check rubric, got \(rubric.count)")
                    }
                    _ = try unique(rubric.map(\.id), "rubric criterion in \(nodeContext)")
                    for criterion in rubric
                    where criterion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        try fail("\(nodeContext): rubric criterion \(criterion.id) has no text")
                    }
                }
            }
            // Reachability + cycle check from the start node.
            var visited = Set<String>()
            var visiting = [String]()
            func visitNode(_ nodeId: String) throws {
                if visiting.contains(nodeId) {
                    try fail("\(context): graph cycle at node \(nodeId)")
                }
                guard !visited.contains(nodeId) else { return }
                visiting.append(nodeId)
                visited.insert(nodeId)
                guard let node = nodesById[nodeId] else {
                    try fail("\(context): unknown node \(nodeId)")
                }
                if !node.complete {
                    for choice in node.choices { try visitNode(choice.next) }
                    if let next = node.next { try visitNode(next) }
                }
                visiting.removeLast()
            }
            try visitNode(dialogue.start)
            guard visited.count == dialogue.nodes.count else {
                let unreachable = dialogue.nodes.map(\.id).filter { !visited.contains($0) }.sorted()
                try fail("\(context): unreachable node(s) \(unreachable.joined(separator: ", "))")
            }
            // No dead ends + explicit end states, path by path.
            var paths = [[String]]()
            func walk(_ nodeId: String, _ trail: [String]) throws {
                guard paths.count < 5000 else {
                    try fail("\(context): dialogue graph too complex")
                }
                guard let node = nodesById[nodeId] else {
                    try fail("\(context): unknown node \(nodeId)")
                }
                let path = trail + [nodeId]
                if node.complete {
                    paths.append(path)
                    return
                }
                var successors = node.choices.map(\.next)
                if let open = node.next { successors.append(open) }
                guard !successors.isEmpty else {
                    try fail("\(context): node \(nodeId) is a dead end (no route on from a non-end node)")
                }
                for successor in successors {
                    guard !path.contains(successor) else {
                        try fail("\(context): graph cycle at \(successor)")
                    }
                    try walk(successor, path)
                }
            }
            try walk(dialogue.start, [])
            guard paths.allSatisfy({ nodesById[$0.last ?? ""]?.complete == true }) else {
                try fail("\(context): some path never reaches an explicit end state")
            }
            guard !paths.isEmpty else {
                try fail("\(context): no path from start to an end state")
            }
            // Required turns not skippable: every path lands on an end state
            // with at least three learner turns; no node repeats on a path and
            // every turn follows the graph edges (both guaranteed by `walk`).
            for path in paths {
                let turns = path.filter { !nodesById[$0]!.complete }
                if dialogue.hostLessonId != nil && turns.count < 3 {
                    try fail("\(context): path \(path.joined(separator: " → ")) has only \(turns.count) learner turn(s); hosted exchanges need at least 3")
                }
            }
            // Hosted exchanges must teach both moves and author recovery
            // routes off every misunderstanding.
            if dialogue.hostLessonId != nil {
                let clarification = dialogue.nodes.filter { $0.kind == .clarification }
                let misunderstandings = dialogue.nodes.filter { $0.kind == .misunderstanding }
                guard !clarification.isEmpty else {
                    try fail("\(context): hosted exchange needs an ask-for-clarification turn")
                }
                guard !misunderstandings.isEmpty else {
                    try fail("\(context): hosted exchange needs a misunderstanding the learner must repair")
                }
                for node in misunderstandings {
                    guard node.choices.contains(where: { nodesById[$0.next]?.kind == .recovery }) else {
                        try fail("\(context): misunderstanding node \(node.id) has no authored recovery route (a choice targeting a recovery node)")
                    }
                }
                let recoveryNodes = dialogue.nodes.filter { $0.kind == .recovery }
                guard recoveryNodes.allSatisfy({ !$0.complete && !$0.choices.isEmpty }) else {
                    try fail("\(context): a recovery node must be a repair turn with choices leading back on")
                }
            }
        }

        // Checkpoint task bank (5.3A): stage-end tasks gate Foundation and
        // Developing. Items live in the bank only — a lesson step must never
        // reference a checkpoint item, and checkpoint items must not collide
        // with any other content id. A checkpoint declares the modality
        // coverage it actually contains (declared ⊇ exercised).
        _ = try unique(pack.checkpoints.map(\.id), "checkpoint")
        var checkpointItemIds = Set<String>()
        for checkpoint in pack.checkpoints {
            guard !checkpoint.items.isEmpty else {
                try fail("checkpoint \(checkpoint.id) has no items")
            }
            for item in checkpoint.items {
                guard checkpointItemIds.insert(item.id).inserted else {
                    try fail("duplicate checkpoint item \(item.id)")
                }
            }
            let declared = Set(checkpoint.modalities)
            let exercised = Set(checkpoint.items.map(\.modality))
            for modality in exercised where !declared.contains(modality) {
                try fail("checkpoint \(checkpoint.id) declares no \(modality.rawValue) slot but ships a \(modality.rawValue) item")
            }
            for item in checkpoint.items {
                switch item {
                case .reading(let r):
                    guard !r.questions.isEmpty else {
                        try fail("checkpoint item \(r.id) has no questions")
                    }
                    _ = try unique(
                        r.questions.map(\.id), "checkpoint question in \(r.id)")
                    for question in r.questions {
                        let options = try unique(
                            question.options.map(\.id),
                            "checkpoint answer option in \(question.id)")
                        guard !question.acceptedIds.isEmpty else {
                            try fail("checkpoint question \(question.id) accepts no option")
                        }
                        for accepted in question.acceptedIds where !options.contains(accepted) {
                            try fail("unknown accepted option \(accepted) in checkpoint question \(question.id)")
                        }
                    }
                case .writing:
                    // Free production: never auto-graded, nothing to check.
                    break
                case .speaking(let s):
                    guard (2...4).contains(s.rubric.count) else {
                        try fail("checkpoint item \(s.id) needs a 2-4 point rubric, got \(s.rubric.count)")
                    }
                    _ = try unique(
                        s.rubric.map(\.id), "checkpoint rubric criterion in \(s.id)")
                }
            }
        }
        // Leak check: the bank is unseen material, so no lesson step may
        // hang a checkpoint item off the lesson graph, and an item id must
        // not double as an activity/stimulus/legacy-exercise id.
        let stepActivityIds = Set(pack.lessons.flatMap { lesson in
            lesson.steps.flatMap { step -> [String] in
                var ids = [step.activityId]
                if let supportId = step.supportActivityId { ids.append(supportId) }
                return ids
            }
        })
        for itemId in checkpointItemIds.sorted() {
            if stepActivityIds.contains(itemId) {
                try fail("lesson step references checkpoint item \(itemId)")
            }
            if activitiesById[itemId] != nil
                || stimuliById[itemId] != nil
                || legacyById[itemId] != nil {
                try fail("checkpoint item \(itemId) collides with a content id")
            }
        }

        // ---- Phase 6.1A: sustained reading & listening ----
        // Two additive top-level arrays referenced by lesson steps through
        // `sustainedTextId` / `sustainedListeningId`. Shape rules: ordered
        // unique section markers, exactly one question of each kind with
        // resolvable accepted options, non-empty unique glossary terms, a
        // provenance statement, transcript == sections for listening,
        // language-tagged voice ids with the offline-fallback rule, and no
        // orphaned or cross-referenced material. Old packs (empty arrays)
        // pass through untouched.

        func checkSustainedQuestions(_ questions: [SustainedQuestion],
                                     _ context: String) throws {
            guard questions.count == SustainedQuestionKind.allCases.count else {
                try fail("\(context) must ask exactly one question of each kind (main idea, key detail, speaker intent)")
            }
            let kinds = Set(questions.map(\.kind))
            guard kinds == Set(SustainedQuestionKind.allCases) else {
                try fail("\(context) must ask one main-idea, one key-detail and one speaker-intent question")
            }
            _ = try unique(questions.map(\.id), "question in \(context)")
            for question in questions {
                guard !question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) question \(question.id) has no question text")
                }
                let options = try unique(question.options.map(\.id),
                                         "question option in \(context)")
                guard question.options.count >= 2 else {
                    try fail("\(context) question \(question.id) needs at least two options")
                }
                for option in question.options
                where option.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try fail("\(context) question \(question.id) option \(option.id) has no text")
                }
                guard !question.acceptedIds.isEmpty else {
                    try fail("\(context) question \(question.id) accepts no option")
                }
                for accepted in question.acceptedIds where !options.contains(accepted) {
                    try fail("\(context) question \(question.id) accepts unknown option \(accepted)")
                }
            }
        }

        func checkSustainedGlossary(_ entries: [SustainedGlossaryEntry],
                                    _ context: String) throws {
            guard (4...8).contains(entries.count) else {
                try fail("\(context) must ship a 4-8 entry glossary, got \(entries.count)")
            }
            _ = try unique(entries.map(\.term), "glossary term in \(context)")
            for entry in entries {
                guard !entry.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !entry.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { try fail("\(context) glossary entry \(entry.term) lacks term or definition") }
            }
        }

        func checkSustainedMarkers(_ sections: [String], _ context: String) throws {
            _ = try unique(sections, "section marker in \(context)")
            let ints = sections.map { Int($0.trimmingCharacters(in: .whitespaces)) }
            if ints.allSatisfy({ $0 != nil }) {
                let asInt = ints.map { $0! }
                if asInt != asInt.sorted() {
                    try fail("section markers out of order in \(context)")
                }
            }
        }

        let sustainedTextIds = try unique(
            pack.sustainedTexts.map(\.id), "sustained text")
        let sustainedListeningIds = try unique(
            pack.sustainedListenings.map(\.id), "sustained listening")
        for id in sustainedTextIds where sustainedListeningIds.contains(id) {
            try fail("sustained id \(id) collides across reading and listening")
        }
        let checkpointIds = Set(pack.checkpoints.map(\.id))
        for id in sustainedTextIds.union(sustainedListeningIds) {
            if activitiesById[id] != nil || stimuliById[id] != nil
                || legacyById[id] != nil || checkpointIds.contains(id)
                || checkpointItemIds.contains(id) {
                try fail("sustained id \(id) collides with a content id")
            }
        }

        for text in pack.sustainedTexts {
            let context = "sustained text \(text.id)"
            guard text.sections.count >= 3 else {
                try fail("\(context) must have at least three paragraphs/sections (multi-paragraph), got \(text.sections.count)")
            }
            try checkSustainedMarkers(text.sections.map(\.marker), context)
            for section in text.sections {
                guard !section.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) has no heading")
                }
                guard !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) has no body")
                }
                guard !section.accessibilityLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) has no accessibility label")
                }
            }
            guard !text.accessibleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                try fail("\(context) has no accessibleSummary (section-list label)")
            }
            try checkSustainedGlossary(text.glossary, context)
            guard !text.provenance.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !text.provenance.date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { try fail("\(context) lacks a provenance statement/date") }
            try checkSustainedQuestions(text.questions, context)
        }
        if !pack.sustainedTexts.isEmpty {
            let genres = Set(pack.sustainedTexts.map(\.genre))
            guard genres == Set(SustainedGenre.allCases) else {
                try fail("sustained texts must cover the three pilot genres (message-thread, short-article, personal-narrative), got \(genres.map(\.rawValue).sorted().joined(separator: ", "))")
            }
        }

        let languageRoot = pack.language.rawValue.lowercased()
        for passage in pack.sustainedListenings {
            let context = "sustained listening \(passage.id)"
            guard passage.sections.count >= 4 else {
                try fail("\(context) must have at least four sections (multi-minute material), got \(passage.sections.count)")
            }
            try checkSustainedMarkers(passage.sections.map(\.marker), context)
            let voiceIds = Set(passage.sections.map(\.voiceId))
            guard voiceIds.count >= 2 else {
                try fail("\(context) must use at least two distinct voices across its sections")
            }
            for section in passage.sections {
                guard !section.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) has no heading")
                }
                guard !section.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) has no text to synthesise")
                }
                guard !section.voiceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("\(context) section \(section.marker) declares an empty voice id")
                }
                let language = section.languageCode.lowercased()
                guard language.hasPrefix(languageRoot + "-") else {
                    try fail("\(context) section \(section.marker) languageCode \(section.languageCode) is not a \(languageRoot)-tagged language")
                }
                guard section.voiceId.lowercased().contains(language) else {
                    try fail("\(context) section \(section.marker) voice id \(section.voiceId) does not carry its language tag \(section.languageCode)")
                }
                guard section.accessibilityLabel.lowercased().contains("synth") else {
                    try fail("\(context) section \(section.marker) must label its voice as synthesised in its accessibility label")
                }
            }
            guard !passage.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                try fail("\(context) has no transcript")
            }
            let expected = passage.sections.map(\.text).joined(separator: "\n\n")
            guard PackValidator.collapsedWhitespace(passage.transcript)
                    == PackValidator.collapsedWhitespace(expected) else {
                try fail("\(context) transcript must equal the section texts joined in order")
            }
            guard !passage.accessibleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                try fail("\(context) has no accessibleSummary")
            }
            try checkSustainedGlossary(passage.glossary, context)
            guard !passage.provenance.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !passage.provenance.date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { try fail("\(context) lacks a provenance statement/date") }
            try checkSustainedQuestions(passage.questions, context)
        }

        // Host binding + orphan discipline: every lesson step that names a
        // sustained id must resolve it (at most one per step), and every
        // authored passage must be reachable from a lesson step.
        var boundTexts = Set<String>()
        var boundListenings = Set<String>()
        for lesson in pack.lessons {
            for step in lesson.steps {
                guard !(step.sustainedTextId != nil && step.sustainedListeningId != nil) else {
                    try fail("step \(step.id) in lesson \(lesson.id) binds both a sustained text and a sustained listening")
                }
                if let textId = step.sustainedTextId {
                    guard sustainedTextIds.contains(textId) else {
                        try fail("step \(step.id) in lesson \(lesson.id) references unknown sustained text \(textId)")
                    }
                    boundTexts.insert(textId)
                }
                if let listeningId = step.sustainedListeningId {
                    guard sustainedListeningIds.contains(listeningId) else {
                        try fail("step \(step.id) in lesson \(lesson.id) references unknown sustained listening \(listeningId)")
                    }
                    boundListenings.insert(listeningId)
                }
            }
        }
        for text in pack.sustainedTexts where !boundTexts.contains(text.id) {
            try fail("orphaned sustained text \(text.id)")
        }
        for passage in pack.sustainedListenings where !boundListenings.contains(passage.id) {
            try fail("orphaned sustained listening \(passage.id)")
        }
    }

    /// Whitespace-insensitive comparable form for paragraph text — used to
    /// verify a listening transcript equals its section texts joined.
    private static func collapsedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

// MARK: - Sustained material lookups (Phase 6.1B)
//
// Tiny additive accessors for the lesson lane views, alongside the content
// lookups in LessonSession.swift. Old packs (empty arrays) return nil exactly
// like an unknown id would; no decoding or storage behaviour changes.

extension CoursePack {
    func sustainedText(id: String) -> SustainedText? {
        sustainedTexts.first { $0.id == id }
    }

    func sustainedListening(id: String) -> SustainedListening? {
        sustainedListenings.first { $0.id == id }
    }

    // MARK: Dialogue lookups (Phase 6.3)

    func dialogue(id: String) -> Dialogue? {
        dialogues.first { $0.id == id }
    }

    /// The exchange a lesson hosts for conversation practice, if any.
    func dialogue(hostedBy lessonId: String) -> Dialogue? {
        dialogues.first { $0.hostLessonId == lessonId }
    }

    /// The first step (across every lesson) that hosts an activity, or
    /// nil when no lesson step binds it.
    func steps(hosting activityId: String) -> LessonStep? {
        for lesson in lessons {
            if let step = lesson.steps.first(where: { $0.activityId == activityId }) {
                return step
            }
        }
        return nil
    }
}

extension Dialogue {
    func node(id: String) -> DialogueNode? {
        nodes.first { $0.id == id }
    }
}
