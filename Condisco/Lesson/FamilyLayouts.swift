import SwiftUI

// MARK: - Lesson family layouts
//
// Pure presentation, mirroring the web `layouts/` directory: the lesson
// objective is framed per family, the step's stimulus sits in a labeled
// context card, and the activity renders below. No engine knowledge, no
// grading, no persistence — the player drives everything.

/// Display name for a lesson family, used for badges and labels.
func familyDisplayName(_ family: LessonFamily) -> String {
    switch family {
    case .discovery: return "Discovery"
    case .story: return "Story"
    case .conversation: return "Conversation"
    case .listening: return "Listening"
    case .construction: return "Construction"
    case .scene: return "Scene"
    case .mission: return "Mission"
    case .recall: return "Recall"
    }
}

/// The context label the web player uses per family ("Story" / "Dialogue" /
/// "Audio" instead of the generic "Context").
func familyContextLabel(_ family: LessonFamily) -> String {
    switch family {
    case .story: return "Story"
    case .conversation: return "Dialogue"
    case .listening: return "Audio"
    default: return "Context"
    }
}

/// An open context card: the stimulus rendered prominently under a
/// small-caps family label, instead of hidden in a disclosure.
struct FamilyContextCard<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(DesignTokens.text(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.muted)
                content
            }
        }
    }
}

/// Conversation goal banner: the lesson objective framed as what the
/// learner will be able to do by the end of the dialogue.
struct ConversationGoalBanner: View {
    let objective: String

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR GOAL")
                    .font(DesignTokens.text(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.primary)
                Text(objective)
                    .font(DesignTokens.text(16, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkDeep)
            }
        }
    }
}

/// Small solid badge marking a non-discovery lesson's family in lists.
struct FamilyBadge: View {
    let family: LessonFamily

    var body: some View {
        Text(familyDisplayName(family).uppercased())
            .font(DesignTokens.text(11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(DesignTokens.stock)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DesignTokens.primary)
            .cornerRadius(6)
    }
}

// MARK: - Lesson scene art
//
// Steven's lesson illustrations, bundled under Content/images/scenes/.
// A lesson whose id names a depicted situation shows its scene art at the
// top of the player — the native equivalent of the web GuidedSession's
// scene framing. Lessons with no matching situation show no art.
//
// Mirrors the web app's scenes.ts: keyed by the lesson-id segment between
// the language prefix and the family suffix, exact semantic matches only —
// no guessing at near-miss keywords (food-foundation is not a café counter).

/// Lesson-id segment → bundled scene file.
private let sceneArtByLessonKey: [String: String] = [
    "cafe-requests": "images/scenes/ordering-coffee.jpg",
    "cafe-order": "images/scenes/ordering-coffee.jpg",
    "cafe": "images/scenes/ordering-coffee.jpg",
    "emergency": "images/scenes/minor-emergency.jpg",
    "directions": "images/scenes/directions.jpg",
    "transport": "images/scenes/station-counter.jpg",
]

/// Family suffixes stripped before the lesson-key lookup.
private let lessonKeySuffixes = ["-foundation", "-construction", "-mission", "-recall"]

/// Bundle URL of the scene illustration for a lesson id, or nil when the
/// lesson depicts no bundled situation.
func sceneArtURL(forLessonId id: String) -> URL? {
    var key = id
    // Strip the two-letter language prefix: "fr-cafe-order-foundation" -> "cafe-order-foundation".
    if key.count > 3 {
        let third = key.index(key.startIndex, offsetBy: 2)
        if key[third] == "-" {
            key = String(key[key.index(after: third)...])
        }
    }
    // Strip the family suffix: "cafe-order-foundation" -> "cafe-order".
    for suffix in lessonKeySuffixes where key.hasSuffix(suffix) {
        key = String(key.dropLast(suffix.count))
        break
    }
    guard let file = sceneArtByLessonKey[key] else { return nil }
    return MediaResolver.bundleURL(for: file)
}

/// Framed scene illustration shown at the top of a lesson — a printed
/// photograph set into the page: the art sits on a cream matte with an
/// ink keyline and the system's hard offset shadow.
struct SceneArtCard: View {
    let url: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .padding(10)
                .background(DesignTokens.stock)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .shadow(color: DesignTokens.ink, radius: 0, x: 5, y: 5)
                .accessibilityHidden(true)
        }
    }
}
