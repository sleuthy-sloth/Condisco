import SwiftUI

// MARK: - Flow layout (for inline cloze)

/// A simple wrapping layout so cloze blanks sit inline in the sentence.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.size.width, height: frame.size.height))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight), frames)
    }
}

// MARK: - Text response

struct TextResponseActivityView: View {
    let activity: TextActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool
    let onAssist: (AssistanceKind) -> Void

    @State private var revealed = false

    private var text: String {
        if case .text(let value) = draft { return value }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your answer")
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
                // Label of the editor below, so VoiceOver pairs them instead
                // of announcing the caption and a nameless empty field.
                .accessibilityHidden(true)
            TextEditor(text: Binding(
                get: { text },
                set: { draft = .text($0) }
            ))
            .font(DesignTokens.text(17))
            .foregroundStyle(DesignTokens.ink)
            .frame(minHeight: 110)
            .padding(8)
            .background(DesignTokens.stock)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignTokens.edge, lineWidth: 1.5)
            )
            .disabled(disabled)
            .accessibilityLabel("Your answer")

            if revealed {
                Text(activity.answer.answers.joined(separator: " / "))
                    .font(DesignTokens.text(16))
                    .foregroundStyle(DesignTokens.ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.primarySoft)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.primary, lineWidth: 1.5)
                    )
            } else {
                StudioSecondaryButton("Reveal a model answer") {
                    revealed = true
                    onAssist(.model)
                }
            }
        }
    }
}

// MARK: - Inline cloze

struct InlineClozeActivityView: View {
    let activity: ClozeActivity
    @Binding var draft: AttemptResponse?
    let disabled: Bool

    private var values: [String: String] {
        if case .cloze(let values) = draft { return values }
        return [:]
    }

    private func setValue(_ name: String, _ value: String) {
        var next = values
        next[name] = value
        draft = .cloze(values: next)
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(activity.segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let string):
                    Text(string)
                        .font(DesignTokens.text(17))
                        .foregroundStyle(DesignTokens.ink)
                case .blank(let name, let label):
                    TextField(label, text: Binding(
                        get: { values[name] ?? "" },
                        set: { setValue(name, $0) }
                    ))
                    .font(DesignTokens.text(17))
                    .foregroundStyle(DesignTokens.ink)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 70, maxWidth: 150)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(DesignTokens.stock2)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                    )
                    .disabled(disabled)
                    .accessibilityLabel(label)
                }
            }
        }
        .padding(4)
    }
}
