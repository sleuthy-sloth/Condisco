import SwiftUI

// MARK: - Activity views
//
// SwiftUI renderers for every schema-v2 activity kind, in the warm Studio
// idiom: cream stock, terracotta accent, hard offset shadows, no blur.
// Each view edits a shared `AttemptResponse` draft and reports assistance
// through `onAssist`; the player owns submit/advance.

// MARK: Shared bits

/// Warm Studio primary button: terracotta fill, cream text, hard shadow.
struct StudioPrimaryButton: View {
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.text(17, weight: .semibold))
                .foregroundStyle(DesignTokens.stock)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(disabled ? DesignTokens.muted : DesignTokens.primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .shadow(color: DesignTokens.ink, radius: 0, x: 3, y: 3)
        }
        .disabled(disabled)
    }
}

/// Warm Studio secondary button: stock fill, ink edge, hard shadow.
struct StudioSecondaryButton: View {
    let label: String
    let disabled: Bool
    let action: () -> Void

    init(_ label: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(DesignTokens.stock)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.edge, lineWidth: 1.5)
                )
                .shadow(color: DesignTokens.ink, radius: 0, x: 2, y: 2)
        }
        .disabled(disabled)
    }
}

/// Selectable option row: checkbox/radio styling in warm Studio.
struct OptionRow: View {
    let text: String
    let selected: Bool
    let multi: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if multi {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .background(selected ? DesignTokens.primary : Color.clear)
                            .cornerRadius(4)
                        if selected {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DesignTokens.stock)
                        }
                    } else {
                        Circle()
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if selected {
                            Circle()
                                .fill(DesignTokens.primary)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                Text(text)
                    .font(DesignTokens.text(16))
                    .foregroundStyle(DesignTokens.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(selected ? DesignTokens.primarySoft : DesignTokens.stock)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? DesignTokens.primary : DesignTokens.edgeSoft, lineWidth: 1.5)
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Think gate

/// The think-first gate. Clearing it is a commitment, not assistance: the
/// player deliberately does not report it through `onAssist`.
struct ThinkGateView: View {
    let onClear: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Think first — don't write yet.")
                    .font(DesignTokens.display(19))
                    .foregroundStyle(DesignTokens.inkDeep)
                Text("Say it in your head, out loud, or to whoever is nearby. There is nothing to memorize; build it from what this lesson already gave you.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.ink)
                StudioPrimaryButton(label: "I've thought about it — let me answer", disabled: false, action: onClear)
            }
        }
    }
}

// MARK: - Dispatcher

/// Renders the right activity view for the step, including the hint area.
/// Excludes information, self-compare, legacy, and scene-selection from the
/// hint button, mirroring the web player.
struct ActivityView: View {
    let activity: Activity
    let stimulus: Stimulus?
    let pack: CoursePack
    let audioPlayer: LessonAudioPlayer
    @Binding var draft: AttemptResponse?
    let disabled: Bool
    let onAssist: (AssistanceKind) -> Void

    @State private var hintRevealed = false

    private var hintable: Bool {
        switch activity {
        case .information, .selfCompare, .legacy, .sceneSelection:
            return false
        default:
            return !(activity.base?.hints.isEmpty ?? true)
        }
    }

    /// Model audio for the self-compare step, when the pack provides one.
    private var modelAudioURL: URL? {
        guard case .selfCompare(let spec) = activity,
              let mediaId = spec.modelAudioId,
              let media = pack.media(id: mediaId),
              case .audio(_, let url, _, _, _) = media else { return nil }
        return MediaResolver.bundleURL(for: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hintable {
                if hintRevealed {
                    Text(activity.base?.hints.first ?? "")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.muted)
                        .padding(10)
                        .background(DesignTokens.stock2)
                        .cornerRadius(8)
                } else {
                    StudioSecondaryButton("Hint") {
                        hintRevealed = true
                        onAssist(.hint)
                    }
                }
            }

            switch activity {
            case .information(let spec):
                InformationActivityView(activity: spec)
            case .selection(let spec):
                SelectionActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .ordering(let spec):
                OrderingActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .matching(let spec):
                MatchingActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .cloze(let spec):
                InlineClozeActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .dialogueChoice(let spec):
                DialogueChoiceActivityView(activity: spec, draft: $draft, disabled: disabled)
            case .text(let spec):
                TextResponseActivityView(activity: spec, draft: $draft, disabled: disabled, onAssist: onAssist)
            case .selfCompare(let spec):
                SelfCompareActivityView(activity: spec, draft: $draft, disabled: disabled,
                                        modelAudioURL: modelAudioURL, audioPlayer: audioPlayer,
                                        onAssist: onAssist)
            case .sceneSelection(let spec):
                SceneSelectionActivityView(activity: spec, stimulus: stimulus, draft: $draft, disabled: disabled)
            case .legacy:
                Text("This player does not support legacy activities yet.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }
}

// MARK: - Information

struct InformationActivityView: View {
    let activity: InformationActivity

    var body: some View {
        Text(activity.body)
            .font(DesignTokens.text(16))
            .foregroundStyle(DesignTokens.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Selection

struct SelectionActivityView: View {
    let activity: SelectionActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var ids: [String] {
        if case .selection(let ids) = draft { return ids }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activity.multiple ? "Choose all that apply" : "Choose one answer")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            ForEach(activity.options, id: \.id) { option in
                OptionRow(
                    text: option.text,
                    selected: ids.contains(option.id),
                    multi: activity.multiple,
                    disabled: disabled
                ) {
                    var next = ids
                    if activity.multiple {
                        if next.contains(option.id) {
                            next.removeAll { $0 == option.id }
                        } else {
                            next.append(option.id)
                        }
                    } else {
                        next = [option.id]
                    }
                    draft = .selection(ids: next)
                }
            }
        }
    }
}

// MARK: - Dialogue choice

struct DialogueChoiceActivityView: View {
    let activity: DialogueChoiceActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var chosenId: String? {
        if case .selection(let ids) = draft { return ids.first }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose your reply")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            ForEach(activity.options, id: \.id) { option in
                OptionRow(
                    text: option.text,
                    selected: chosenId == option.id,
                    multi: false,
                    disabled: disabled
                ) {
                    draft = .selection(ids: [option.id])
                }
            }
        }
    }
}

// MARK: - Scene selection

/// Region checkboxes. The scene image itself renders in the stimulus
/// context; when the image is unavailable the text alternative stands in.
struct SceneSelectionActivityView: View {
    let activity: SceneSelectionActivity
    let stimulus: Stimulus?
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var ids: [String] {
        if case .selection(let ids) = draft { return ids }
        return []
    }

    private var regions: [SceneRegion] {
        guard let stimulus, case .scene(_, _, _, let regions, _) = stimulus else { return [] }
        return regions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select the matching parts of the scene")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            if regions.isEmpty {
                Text("The scene for this activity is unavailable.")
                    .font(DesignTokens.text(15))
                    .foregroundStyle(DesignTokens.attentionInk)
            } else {
                ForEach(regions, id: \.id) { region in
                    OptionRow(
                        text: region.label,
                        selected: ids.contains(region.id),
                        multi: true,
                        disabled: disabled
                    ) {
                        var next = ids
                        if next.contains(region.id) {
                            next.removeAll { $0 == region.id }
                        } else {
                            next.append(region.id)
                        }
                        draft = .selection(ids: next)
                    }
                }
            }
        }
    }
}
