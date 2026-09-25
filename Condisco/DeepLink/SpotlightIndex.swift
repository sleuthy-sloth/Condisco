import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

// MARK: - Spotlight indexing
//
// Indexes every bundled lesson in Core Spotlight so a Spotlight search for a
// lesson title opens it directly. Each item's unique identifier IS its deep
// link (`condisco://lesson/<packId>/<lessonId>`), so a tap resolves through the
// same `DeepLinkRouter` path as Siri and external links.
//
// The index is version-stamped: a fingerprint of pack ids, pack versions, and
// lesson ids+revisions is persisted after each successful indexing, and the
// whole lesson domain is re-indexed only when the fingerprint changes.

enum SpotlightIndex {
    private static let fingerprintKey = "condisco.spotlightFingerprint.v2"
    private static let domainIdentifier = "condisco.lessons"

    /// Indexes all lessons if the packs changed since the last indexing.
    /// Best-effort and silent — call once per launch, e.g. from `.task`.
    static func indexIfNeeded() {
        do {
            let packs = try PackLoader.loadPacks()
            let fingerprint = Self.fingerprint(packs: packs)
            guard UserDefaults.standard.string(forKey: fingerprintKey) != fingerprint else { return }
            index(packs: packs) { indexed in
                if indexed {
                    UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
                }
            }
        } catch {
            // Best-effort: Spotlight indexing never surfaces errors.
        }
    }

    /// Deterministic stamp of everything the index derives from.
    private static func fingerprint(packs: [CoursePack]) -> String {
        packs
            .map { pack in
                let lessons = pack.lessons
                    .map { "\($0.id)@\($0.revision)" }
                    .sorted()
                    .joined(separator: ",")
                return "\(pack.id):\(pack.version):\(lessons)"
            }
            .sorted()
            .joined(separator: "|")
    }

    private static func index(packs: [CoursePack], completion: @escaping (Bool) -> Void) {
        let items: [CSSearchableItem] = packs.flatMap { pack in
            pack.lessons.map { lesson in
                let unitTitle = pack.units.first { $0.id == lesson.unitId }?.title ?? ""
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = lesson.title
                attributes.contentDescription =
                    "\(pack.language.displayName) · \(unitTitle)\n\(lesson.objective)"
                attributes.keywords = [
                    pack.language.displayName,
                    pack.language.slug,
                    pack.title,
                    unitTitle,
                    "Condisco",
                ]
                attributes.contentURL = URL(string: "condisco://lesson/\(pack.id)/\(lesson.id)")
                return CSSearchableItem(
                    uniqueIdentifier: "condisco://lesson/\(pack.id)/\(lesson.id)",
                    domainIdentifier: domainIdentifier,
                    attributeSet: attributes
                )
            }
        }
        let store = CSSearchableIndex.default()
        store.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { _ in
            store.indexSearchableItems(items) { error in
                completion(error == nil)
            }
        }
    }

    // MARK: - Saved phrases

    private static let phraseFingerprintKey = "condisco.spotlightPhraseFingerprint.v2"
    private static let phraseDomainIdentifier = "condisco.phrases"

    /// Indexes the learner's saved phrasebook phrases so a Spotlight
    /// search for a kept phrase finds it. Tapping one opens the Saved tab
    /// through `condisco://phrasebook` (the item's unique identifier carries a
    /// fragment so every phrase indexes as its own item).
    /// Best-effort and silent, like the lesson index.
    static func indexPhrasesIfNeeded() {
        Task { @MainActor in
            do {
                let phrases = try LearningStore.inDocuments().savedPhrases()
                let fingerprint = phrases.map(\.id).sorted().joined(separator: ",")
                guard UserDefaults.standard.string(forKey: phraseFingerprintKey) != fingerprint else { return }
                index(phrases: phrases) { indexed in
                    if indexed {
                        UserDefaults.standard.set(fingerprint, forKey: phraseFingerprintKey)
                    }
                }
            } catch {
                // Best-effort: Spotlight indexing never surfaces errors.
            }
        }
    }

    private static func index(phrases: [SavedPhrase], completion: @escaping (Bool) -> Void) {
        let items: [CSSearchableItem] = phrases.map { phrase in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = phrase.target
            var description = phrase.meaning
            if !phrase.source.isEmpty {
                description += "\n\(phrase.source)"
            }
            attributes.contentDescription = description
            attributes.keywords = [phrase.languageName, "Condisco", "phrasebook"]
            attributes.contentURL = URL(string: "condisco://phrasebook")
            return CSSearchableItem(
                uniqueIdentifier: "condisco://phrasebook#\(phrase.id)",
                domainIdentifier: phraseDomainIdentifier,
                attributeSet: attributes
            )
        }
        let store = CSSearchableIndex.default()
        store.deleteSearchableItems(withDomainIdentifiers: [phraseDomainIdentifier]) { _ in
            store.indexSearchableItems(items) { error in
                completion(error == nil)
            }
        }
    }
}
