import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Practice library (8.2 §5-§9)
//
// The Library segment of the Review tab: a learner-imported reading
// library that lives entirely on device. Content is untrusted input, so
// every entry point (file picker and paste) runs through
// `LibraryImportValidator` before anything is written — an unsupported,
// oversized, or undecodable text is rejected with plain-language copy and
// zero store rows. Documents never sync, never enter the event log, and
// leave the device only through the learner's own explicit exports (§7).

// MARK: Import + save helpers (pure logic, no views)

/// The bundled course languages, for the import sheet's language
/// picker and for phrase display names. Document rows store the
/// `CourseLanguage.slug` ("french", …); the phrases saved from them carry
/// the same slug plus the human name. Everything derives from the registry.
enum LibraryLanguage {
    /// Catalog order — the registry's explicit course order.
    static let all: [CourseLanguage] = CourseRegistry.order

    static func language(slug: String) -> CourseLanguage? {
        CourseRegistry.language(slug: slug)
    }

    /// Display name for a stored document slug (French, Italian, …). The
    /// import sheet's picker only offers the bundled slugs, so the
    /// fallback only defends against a legacy or foreign row — the label
    /// still reads as something (its own capitalization, never English).
    static func displayName(for slug: String) -> String {
        CourseRegistry.displayName(for: slug)
    }
}

/// Pure import-flow helpers: the file-name title heuristic, the reader's
/// selection→phrase trimming, and the single validated commit builder.
/// Nothing here touches UIKit, so the whole import commit path is unit
/// testable.
enum LibraryImport {
    /// Cap on a saved phrase's length, from the reader selection (§11.3).
    /// Longer selections simply don't offer the save button.
    static let maxSelectionLength = 200

    /// A file name minus its extension becomes the import title. Falls
    /// back to the paste default when the name is empty or whitespace,
    /// or when the URL points at a directory — a directory has no file
    /// name to show (Foundation would otherwise hand back the folder's
    /// own name, e.g. "tmp" for "/tmp/").
    static func title(fromFileURL url: URL) -> String {
        guard !url.hasDirectoryPath else { return "Pasted text" }
        let name = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Pasted text" : name
    }

    /// The reader's selected span, trimmed for the save sheet's target
    /// field. Nil when the selection is empty or longer than
    /// `maxSelectionLength` — the floating save button only appears for a
    /// usable span (§6.2).
    static func phraseTarget(from selection: String) -> String? {
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxSelectionLength else {
            return nil
        }
        return trimmed
    }

    /// The one validated import gateway: bytes → validator → document,
    /// used by every entry point and by the confirmation sheet's "Add to
    /// library". `LibraryImportValidator` is the only size/UTF-8 check in
    /// the import path — a failed validation returns `.failure` and the
    /// caller has nothing to write (§5.2).
    static func makeDocument(
        data: Data, title: String, languageSlug: String,
        sourceFileName: String, importedAt: Date
    ) -> Result<ImportedDocument, LibraryImportError> {
        switch LibraryImportValidator.validate(data) {
        case .success(let text):
            let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(ImportedDocument(
                id: UUID().uuidString,
                title: cleanedTitle.isEmpty ? "Untitled" : cleanedTitle,
                content: text,
                byteSize: data.count,
                languageSlug: languageSlug,
                sourceFileName: sourceFileName,
                importedAt: importedAt))
        case .failure(let error):
            return .failure(error)
        }
    }
}

/// The learner's confirmed save: one phrase row plus one provenance link,
/// in one logical action with the link last (§6.5). The phrase's `source`
/// is the document title (read-only provenance) and
/// `sourcePackId`/`sourceLessonId` stay empty so the phrasebook's "open
/// the source lesson" tap never deep-links into a document (§3.3).
@MainActor
enum LibrarySavePhrase {
    static func commit(
        store: LearningStore, document: ImportedDocument,
        target: String, meaning: String, savedAt: Date = Date()
    ) throws -> SavedPhrase {
        let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        // The save sheet disables its button until meaning is non-empty
        // (§6.4); committing with an empty meaning is a programming error.
        precondition(
            !cleanMeaning.isEmpty,
            "meaning is required before a library phrase can be saved")
        let phrase = SavedPhrase(
            id: LearningStore.savedPhraseId(
                languageSlug: document.languageSlug,
                target: cleanTarget, meaning: cleanMeaning),
            languageSlug: document.languageSlug,
            languageName: LibraryLanguage.displayName(for: document.languageSlug),
            target: cleanTarget,
            meaning: cleanMeaning,
            source: document.title,
            savedAt: savedAt)
        try store.savePhrase(phrase)
        try store.linkPhrase(phraseId: phrase.id, documentId: document.id)
        return phrase
    }
}

/// An import waiting at the confirmation sheet: validated text plus the
/// editable title and language. `Identifiable` so the sheet can present
/// by item, like `ImportPreviewView` does.
struct LibraryImportDraft: Identifiable {
    let id = UUID()
    var title: String
    let text: String
    let byteSize: Int
    var languageSlug: String
    let sourceFileName: String
}

// MARK: - Library list

@MainActor
final class LibraryModel: ObservableObject {
    @Published var documents: [ImportedDocument] = []
    @Published var isLoading = true

    func load() {
        documents = (try? LearningStore.inDocuments().documents()) ?? []
        isLoading = false
    }

    func delete(_ document: ImportedDocument) {
        try? LearningStore.inDocuments().deleteDocument(id: document.id)
        load()
    }
}

struct LibraryView: View {
    @Binding var section: ReviewSection
    @StateObject private var model = LibraryModel()
    /// File importer and paste sheet both end here: the validated draft
    /// confirmed in `LibraryImportPreviewView` before anything is written.
    @State private var pendingImport: LibraryImportDraft?
    @State private var showingImporter = false
    @State private var showingPasteSheet = false
    @State private var importErrorMessage: String?
    /// The document a trash tap asked to delete, pending the destructive
    /// confirm (§8.3).
    @State private var deleteCandidate: ImportedDocument?
    @AppStorage("condisco.focusLanguage") private var focusSlug = "french"

    private var defaultLanguageSlug: String {
        LibraryLanguage.language(slug: focusSlug)?.slug ?? "french"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                if model.isLoading {
                    ProgressView()
                        .tint(DesignTokens.primary)
                } else if model.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("Review")
            .safeAreaInset(edge: .top, spacing: 0) {
                ReviewSectionPicker(selection: $section)
            }
            .navigationDestination(for: ImportedDocument.self) { document in
                LibraryDocumentReader(document: document)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    importMenu(label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignTokens.primary)
                    }, accessibilityLabel: "Add text")
                }
            }
            // One sheet per view node so both presentations are reliable:
            // the clipboard entry point here, the confirmation sheet on the
            // stack below.
            .sheet(isPresented: $showingPasteSheet) {
                LibraryPasteSheet { text in
                    showingPasteSheet = false
                    // Defer past the sheet's own dismissal so the import
                    // confirmation can present on the next runloop turn,
                    // like the app's other sheet-to-sheet transitions.
                    Task { @MainActor in
                        beginImport(
                            data: Data(text.utf8),
                            title: "Pasted text",
                            sourceFileName: "")
                    }
                }
            }
        }
        .task { model.load() }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, .utf8PlainText],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .sheet(item: $pendingImport) { draft in
            LibraryImportPreviewView(draft: draft) { edited in
                commitImport(edited)
            }
        }
        .alert(
            "Nothing was imported",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: List

    private var documentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    let count = model.documents.count
                    Text("\(count) \(count == 1 ? "document" : "documents") in your library")
                        .font(DesignTokens.text(13, weight: .medium))
                        .foregroundStyle(DesignTokens.muted)
                    Text("Text you import stays on this device.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                .padding(.horizontal, 4)
                ForEach(model.documents) { document in
                    documentRow(document)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable { model.load() }
        .confirmationDialog(
            "Delete \"\(deleteCandidate?.title ?? "")\"?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { document in
            Button("Delete", role: .destructive) {
                model.delete(document)
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: { _ in
            Text("The text is removed from your library. Phrases you saved from it stay in your Phrasebook.")
        }
    }

    private func documentRow(_ document: ImportedDocument) -> some View {
        PaperCard {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink(value: document) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(DesignTokens.text(16, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkDeep)
                            .multilineTextAlignment(.leading)
                        Text(subtitle(for: document))
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read \"\(document.title)\"")
                Button {
                    deleteCandidate = document
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \"\(document.title)\"")
            }
        }
    }

    /// §9.2 row subtitle: language · character count · import date.
    private func subtitle(for document: ImportedDocument) -> String {
        let language = LibraryLanguage.displayName(for: document.languageSlug)
        let characters = "\(document.content.count.formatted()) "
            + (document.content.count == 1 ? "character" : "characters")
        let imported = "Imported "
            + document.importedAt.formatted(date: .abbreviated, time: .omitted)
        return "\(language) · \(characters) · \(imported)"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                art: .phrases,
                title: "No documents yet",
                message: "Paste a passage or choose a text file to start your own reading library.")
            // The primary action opens the same two-option import menu as
            // the toolbar "+", styled like EmptyStateView's action button.
            importMenu(label: {
                Text("Add text")
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                    .padding(.top, 2)
            }, accessibilityLabel: "Add text")
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    private func importMenu<MenuLabel: View>(
        @ViewBuilder label: () -> MenuLabel, accessibilityLabel: String
    ) -> some View {
        Menu {
            Button {
                showingPasteSheet = true
            } label: {
                Label("Paste text", systemImage: "doc.on.clipboard")
            }
            Button {
                showingImporter = true
            } label: {
                Label("Choose file…", systemImage: "folder")
            }
        } label: {
            label()
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Import flow

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importSelectedFile(url)
        case .failure:
            importErrorMessage = "The file could not be opened. Nothing was changed."
        }
    }

    private func importSelectedFile(_ url: URL) {
        // Files picked from the Files app are security-scoped.
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            importErrorMessage = "The file could not be read. Nothing was changed."
            return
        }
        beginImport(
            data: data,
            title: LibraryImport.title(fromFileURL: url),
            sourceFileName: url.lastPathComponent)
    }

    /// Validates raw bytes through the single import gateway and, on
    /// success, parks them at the confirmation sheet. On failure nothing
    /// is written — the plain error is shown as-is (§5.2).
    private func beginImport(data: Data, title: String, sourceFileName: String) {
        switch LibraryImport.makeDocument(
            data: data, title: title, languageSlug: defaultLanguageSlug,
            sourceFileName: sourceFileName, importedAt: Date()) {
        case .success(let document):
            pendingImport = LibraryImportDraft(
                title: document.title,
                text: document.content,
                byteSize: document.byteSize,
                languageSlug: document.languageSlug,
                sourceFileName: document.sourceFileName)
        case .failure(let error):
            importErrorMessage = error.description
        }
    }

    /// The confirmation sheet's "Add to library": the validated draft
    /// (with the learner's title and language choices) goes through the
    /// same single gateway before the store write, then the list reloads.
    private func commitImport(_ draft: LibraryImportDraft) {
        switch LibraryImport.makeDocument(
            data: Data(draft.text.utf8),
            title: draft.title,
            languageSlug: draft.languageSlug,
            sourceFileName: draft.sourceFileName,
            importedAt: Date()) {
        case .success(let document):
            do {
                try LearningStore.inDocuments().saveDocument(document)
                model.load()
            } catch {
                importErrorMessage =
                    "The text could not be saved. Nothing was imported."
            }
        case .failure(let error):
            importErrorMessage = error.description
        }
    }
}

// MARK: - Document reader

/// The document detail (§6): content rendered in a selectable `UITextView`
/// (SwiftUI's `.textSelection` never hands the selected substring back,
/// §6.1), with a floating "Save phrase" button for a usable selection and
/// a save sheet for the learner-supplied meaning.
struct LibraryDocumentReader: View {
    let document: ImportedDocument
    /// The trimmed, in-range selection, or nil when the current selection
    /// isn't a saveable phrase (§6.2).
    @State private var phraseTarget: String?
    @State private var showingSaveSheet = false

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            SelectableDocumentTextView(
                text: document.content,
                onSelectionChange: { selection in
                    phraseTarget = LibraryImport.phraseTarget(from: selection)
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if phraseTarget != nil {
                Button {
                    showingSaveSheet = true
                } label: {
                    Text("Save phrase")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            LibrarySavePhraseSheet(
                document: document,
                initialTarget: phraseTarget ?? "")
        }
    }
}

/// The reader's text surface: a non-editable, selectable `UITextView`
/// wrapped for SwiftUI. Reports selection changes (debounced, so a tap
/// that only moves the cursor doesn't flash the save affordance) through
/// `onSelectionChange`, which delivers the raw selected substring.
struct SelectableDocumentTextView: UIViewRepresentable {
    let text: String
    var onSelectionChange: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = false
        textView.showsVerticalScrollIndicator = false
        textView.font = UIFontMetrics.default.scaledFont(
            for: UIFont.systemFont(ofSize: 17))
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = UIColor(DesignTokens.inkDeep)
        textView.textContainerInset = UIEdgeInsets(
            top: 8, left: 0, bottom: 24, right: 0)
        textView.text = text
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // The reader text is fixed after navigation; only replace when the
        // document actually changed, so scroll position survives re-renders.
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChange: onSelectionChange)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var onSelectionChange: (String) -> Void
        private var pendingReport: DispatchWorkItem?

        init(onSelectionChange: @escaping (String) -> Void) {
            self.onSelectionChange = onSelectionChange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            pendingReport?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let selected: String
                if let range = textView.selectedTextRange,
                   let value = textView.text(in: range) {
                    selected = value
                } else {
                    selected = ""
                }
                self.onSelectionChange(selected)
            }
            pendingReport = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }
}

// MARK: - Import sheets

/// The paste entry point (§5.1): a `TextEditor` sheet. The clipboard is
/// read only on an explicit tap, as the plain-text representation, to
/// pre-fill the editor — never wirelessly and never automatically.
private struct LibraryPasteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onContinue: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paste a passage you want to read and practise with.")
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.muted)
                    .accessibilityHidden(true)
                TextEditor(text: $text)
                    .font(DesignTokens.text(17))
                    .foregroundStyle(DesignTokens.ink)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(DesignTokens.stock)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.edge, lineWidth: 1.5)
                    )
                    .accessibilityLabel("Paste text")
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DesignTokens.canvas)
            .navigationTitle("Paste text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DesignTokens.text(15, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            text = pasted
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(DesignTokens.primary)
                    }
                    .accessibilityLabel("Paste from clipboard")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    dismiss()
                    onContinue(text)
                } label: {
                    Text("Review text")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }
}

/// The confirmation sheet before a library import writes anything (§5.3):
/// the editable title, the language picker (five bundled slugs, defaulting
/// to the focus language), the character/byte counts, and the privacy
/// line. "Add to library" commits through the single validated gateway.
private struct LibraryImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: LibraryImportDraft
    let onConfirm: (LibraryImportDraft) -> Void

    @State private var title: String
    @State private var languageSlug: String

    init(draft: LibraryImportDraft, onConfirm: @escaping (LibraryImportDraft) -> Void) {
        self.draft = draft
        self.onConfirm = onConfirm
        _title = State(initialValue: draft.title)
        _languageSlug = State(initialValue: draft.languageSlug)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        TextField("Title", text: $title)
                            .font(DesignTokens.text(16))
                            .foregroundStyle(DesignTokens.ink)
                            .padding(10)
                            .background(DesignTokens.stock)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignTokens.edge, lineWidth: 1.5)
                            )
                            .accessibilityLabel("Document title")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Language")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        Picker("Language", selection: $languageSlug) {
                            ForEach(LibraryLanguage.all, id: \.slug) { language in
                                Text(language.displayName).tag(language.slug)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(DesignTokens.text(16))
                        .foregroundStyle(DesignTokens.ink)
                    }

                    Text("\(draft.text.count.formatted()) characters · \(draft.byteSize.formatted()) bytes")
                        .font(DesignTokens.text(15))
                        .foregroundStyle(DesignTokens.ink)

                    Text("This text stays on this device. It is never synced or sent anywhere unless you export your data yourself. You can delete it from your library at any time.")
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(DesignTokens.canvas)
            .navigationTitle("Add to library?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DesignTokens.text(15, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    dismiss()
                    onConfirm(LibraryImportDraft(
                        title: title,
                        text: draft.text,
                        byteSize: draft.byteSize,
                        languageSlug: languageSlug,
                        sourceFileName: draft.sourceFileName))
                } label: {
                    Text("Add to library")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Save-phrase sheet

/// Saves the selected span from a document (§6.3-§6.5): target prefilled
/// from the selection (editable), meaning typed by the learner (required),
/// and the source language and document title shown read-only. Committing
/// runs the single phrase+link action.
private struct LibrarySavePhraseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: ImportedDocument
    @State private var target: String
    @State private var meaning = ""
    @State private var commitErrorMessage: String?

    init(document: ImportedDocument, initialTarget: String) {
        self.document = document
        _target = State(initialValue: initialTarget)
    }

    private var canSave: Bool {
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldGroup("Phrase") {
                        TextEditor(text: $target)
                            .font(DesignTokens.text(17))
                            .foregroundStyle(DesignTokens.ink)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(DesignTokens.stock)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignTokens.edge, lineWidth: 1.5)
                            )
                            .accessibilityLabel("Phrase")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What it means")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        TextEditor(text: $meaning)
                            .font(DesignTokens.text(17))
                            .foregroundStyle(DesignTokens.ink)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(DesignTokens.stock)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignTokens.edge, lineWidth: 1.5)
                            )
                            .accessibilityLabel("What it means")
                        if !canSave {
                            Text("Add what it means so this phrase can be reviewed.")
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.muted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(DesignTokens.text(14, weight: .medium))
                            .foregroundStyle(DesignTokens.muted)
                        Text(document.title)
                            .font(DesignTokens.text(15))
                            .foregroundStyle(DesignTokens.ink)
                        Text(LibraryLanguage.displayName(for: document.languageSlug))
                            .font(DesignTokens.text(13))
                            .foregroundStyle(DesignTokens.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(DesignTokens.canvas)
            .navigationTitle("Save phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DesignTokens.text(15, weight: .medium))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    commit()
                } label: {
                    Text("Save phrase")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.stock)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignTokens.primary)
                        .cornerRadius(12)
                        .opacity(canSave ? 1 : 0.4)
                }
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .alert(
                "Couldn't save this phrase",
                isPresented: Binding(
                    get: { commitErrorMessage != nil },
                    set: { if !$0 { commitErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(commitErrorMessage ?? "")
            }
        }
    }

    private func fieldGroup<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DesignTokens.text(14, weight: .medium))
                .foregroundStyle(DesignTokens.muted)
            content()
        }
    }

    private func commit() {
        do {
            let store = try LearningStore.inDocuments()
            try LibrarySavePhrase.commit(
                store: store, document: document,
                target: target, meaning: meaning)
            dismiss()
        } catch {
            commitErrorMessage = error.localizedDescription
        }
    }
}
