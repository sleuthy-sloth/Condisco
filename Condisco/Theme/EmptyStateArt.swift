import SwiftUI

// MARK: - Empty-state illustrations
//
// Hand-drawn terracotta spot illustrations for the app's empty states:
// a finished review queue, an empty phrasebook, a search with no hits.
// Simple line work in the Warm Studio voice — no gray system symbols
// where the app should feel like itself.

/// Which spot illustration an empty state shows.
enum EmptyArtwork {
    /// All caught up: an almost-closed brush circle, a check, two leaves.
    case rested
    /// No saved phrases yet: an open book.
    case phrases
    /// A search with no hits: a magnifier and a small spark.
    case search
}

/// A terracotta line illustration on a 112pt square.
struct EmptyStateArt: View {
    let art: EmptyArtwork

    var body: some View {
        ZStack {
            switch art {
            case .rested: rested
            case .phrases: openBook
            case .search: magnifier
            }
        }
        .frame(width: 112, height: 112)
        .foregroundStyle(DesignTokens.primary)
        .accessibilityHidden(true)
    }

    private var rested: some View {
        ZStack {
            // Brush circle with a gap at the top right.
            Circle()
                .trim(from: 0.05, to: 0.93)
                .stroke(lineWidth: 5)
                .rotationEffect(.degrees(-52))
                .frame(width: 66, height: 66)
                .offset(y: -6)
            Path { p in
                p.move(to: CGPoint(x: 46, y: 50))
                p.addLine(to: CGPoint(x: 58, y: 62))
                p.addLine(to: CGPoint(x: 80, y: 36))
            }
            .stroke(style: StrokeStyle(
                lineWidth: 6, lineCap: .round, lineJoin: .round))
            // Two small leaves at the circle's base.
            Path { p in
                p.move(to: CGPoint(x: 40, y: 88))
                p.addQuadCurve(
                    to: CGPoint(x: 26, y: 76),
                    control: CGPoint(x: 28, y: 88))
                p.move(to: CGPoint(x: 40, y: 88))
                p.addQuadCurve(
                    to: CGPoint(x: 32, y: 100),
                    control: CGPoint(x: 32, y: 94))
            }
            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }

    private var openBook: some View {
        Path { p in
            // Spine.
            p.move(to: CGPoint(x: 56, y: 26))
            p.addLine(to: CGPoint(x: 56, y: 88))
            // Left page.
            p.move(to: CGPoint(x: 56, y: 30))
            p.addCurve(
                to: CGPoint(x: 18, y: 40),
                control1: CGPoint(x: 42, y: 26),
                control2: CGPoint(x: 30, y: 32))
            p.addLine(to: CGPoint(x: 18, y: 80))
            p.addCurve(
                to: CGPoint(x: 56, y: 70),
                control1: CGPoint(x: 30, y: 72),
                control2: CGPoint(x: 42, y: 66))
            // Right page.
            p.move(to: CGPoint(x: 56, y: 30))
            p.addCurve(
                to: CGPoint(x: 94, y: 40),
                control1: CGPoint(x: 70, y: 26),
                control2: CGPoint(x: 82, y: 32))
            p.addLine(to: CGPoint(x: 94, y: 80))
            p.addCurve(
                to: CGPoint(x: 56, y: 70),
                control1: CGPoint(x: 82, y: 72),
                control2: CGPoint(x: 70, y: 66))
            // Text lines.
            p.move(to: CGPoint(x: 28, y: 52))
            p.addLine(to: CGPoint(x: 46, y: 48))
            p.move(to: CGPoint(x: 28, y: 62))
            p.addLine(to: CGPoint(x: 46, y: 58))
            p.move(to: CGPoint(x: 66, y: 48))
            p.addLine(to: CGPoint(x: 84, y: 52))
            p.move(to: CGPoint(x: 66, y: 58))
            p.addLine(to: CGPoint(x: 84, y: 62))
        }
        .stroke(style: StrokeStyle(
            lineWidth: 4.5, lineCap: .round, lineJoin: .round))
    }

    private var magnifier: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .frame(width: 56, height: 56)
                .offset(x: -12, y: -12)
            Path { p in
                p.move(to: CGPoint(x: 70, y: 70))
                p.addLine(to: CGPoint(x: 94, y: 94))
            }
            .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
            // A small spark: nothing found, keep looking.
            Path { p in
                p.move(to: CGPoint(x: 88, y: 20))
                p.addLine(to: CGPoint(x: 88, y: 32))
                p.move(to: CGPoint(x: 82, y: 26))
                p.addLine(to: CGPoint(x: 94, y: 26))
            }
            .stroke(style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }
}

/// A complete empty state: spot illustration, serif title, a quiet
/// explanation, and an optional action. Every "nothing here yet" screen
/// shares this shape so the calm tone stays consistent.
struct EmptyStateView: View {
    let art: EmptyArtwork
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            EmptyStateArt(art: art)
            Text(title)
                .font(DesignTokens.display(20))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(message)
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
