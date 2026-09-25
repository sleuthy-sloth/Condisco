import SwiftUI

// MARK: - Welcome (first-run onboarding)
//
// Shown once, the first time the app opens: a warm splash, a language
// pick, and a choice between starting fresh or taking the placement
// check. Completion is recorded in UserDefaults; ContentView gates the
// tab bar behind it. Everything here is offline and judgment-free.

struct WelcomeFlow: View {
    /// Called when onboarding finishes. When the user placed into a
    /// lesson, its pack and lesson id come back so ContentView can
    /// open the player straight away.
    var onComplete: (CoursePack?, String?) -> Void

    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"
    @State private var step: Step = .splash
    @State private var packs: [CoursePack] = []
    @State private var loadError: String?
    @State private var showPlacement = false

    private enum Step { case splash, language, experience }

    private var selectedPack: CoursePack? {
        packs.first(where: { $0.language.slug == focusSlug }) ?? packs.first
    }

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            switch step {
            case .splash: splash
            case .language: languageStep
            case .experience: experienceStep
            }
        }
        .task { loadPacks() }
        .fullScreenCover(isPresented: $showPlacement) {
            if let pack = selectedPack {
                PlacementTestView(
                    pack: pack,
                    onDone: { lessonId in onComplete(pack, lessonId) },
                    onSkip: { onComplete(nil, nil) }
                )
            }
        }
    }

    private func loadPacks() {
        do {
            packs = try PackLoader.loadPacks()
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: Splash

    private var splash: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 12)
                        mascotArt(width: min(geometry.size.width * 0.78, 330))
                            .padding(.bottom, 8)
                        Text("Condisco")
                            .font(DesignTokens.display(48))
                            .foregroundStyle(DesignTokens.inkDeep)
                            .padding(.bottom, 8)
                        Text("Learn without limits.")
                            .font(DesignTokens.display(25, weight: .medium))
                            .foregroundStyle(DesignTokens.primaryStrong)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 14)
                        Text("Pick a language. We'll help you find your first step.")
                            .font(DesignTokens.text(16))
                            .foregroundStyle(DesignTokens.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, geometry.size.height - 108))
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 12) {
                    StudioPrimaryButton(label: "Choose a language", disabled: false) {
                        step = .language
                    }
                    Text("Free to learn. Ready offline.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
            }
        }
    }

    private func mascotArt(width: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(DesignTokens.primarySoft.opacity(0.7))
                .frame(width: width * 0.76, height: width * 0.76)
                .accessibilityHidden(true)
            Image("CondiscoBee")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: width)
                .accessibilityLabel("A smiling honeybee reading a book")
        }
        .frame(width: width, height: width)
    }

    // MARK: Language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which language are you learning?")
                .font(DesignTokens.display(26))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.top, 72)
            if let loadError {
                Text(loadError)
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
            }
            ForEach(packs, id: \.id) { pack in
                Button {
                    focusSlug = pack.language.slug
                } label: {
                    PaperCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.language.displayName)
                                    .font(DesignTokens.text(17, weight: .semibold))
                                    .foregroundStyle(DesignTokens.inkDeep)
                                Text(pack.title)
                                    .font(DesignTokens.text(13))
                                    .foregroundStyle(DesignTokens.muted)
                            }
                            Spacer()
                            if pack.language.slug == focusSlug {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.primary)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            StudioPrimaryButton(label: "Continue", disabled: false) {
                step = .experience
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Experience

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much \(selectedPack?.language.displayName ?? "of the language") do you know?")
                .font(DesignTokens.display(26))
                .foregroundStyle(DesignTokens.inkDeep)
                .padding(.top, 72)
            experienceCard(
                title: "I'm starting fresh",
                detail: "Begin with your first mission. No experience needed.",
                icon: "sunrise"
            ) {
                let pack = selectedPack
                onComplete(pack, pack?.lessons.first?.id)
            }
            experienceCard(
                title: "I know some already",
                detail: "A quick check drawn from across the course — we'll suggest your starting lesson, and you always have the final say.",
                icon: "chart.bar"
            ) {
                showPlacement = true
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func experienceCard(
        title: String, detail: String, icon: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            PaperCard {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.primary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(DesignTokens.text(17, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                        Text(detail)
                            .font(DesignTokens.text(14))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.muted)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
