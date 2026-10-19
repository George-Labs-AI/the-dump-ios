import SwiftUI

// Create a routine, in the same steps as the web's /routines/new page:
// 1. a name and description, 2. the notes it reads, 3. a preview of those
// notes and Create, then the "Connect your runner" screen. Presented as a
// sheet from the routines list.

struct RoutineCreateFlowView: View {
    /// Called once the server has saved the routine, so the list can reload.
    var onCreated: (RoutineSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RoutineCreateViewModel()
    @State private var path: [Step] = []

    enum Step: Hashable {
        case notes
        case preview
        case connect
    }

    var body: some View {
        NavigationStack(path: $path) {
            RoutineDetailsStepView(viewModel: viewModel) {
                path.append(.notes)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .notes:
                    RoutineChooseNotesStepView(viewModel: viewModel) {
                        path.append(.preview)
                    }
                case .preview:
                    RoutinePreviewStepView(viewModel: viewModel)
                case .connect:
                    if let routine = viewModel.createdRoutine {
                        RoutineConnectView(routine: RoutineConnectView.Routine(routine)) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isCreating)
        .onChange(of: viewModel.createdRoutine) { _, routine in
            guard let routine else { return }
            onCreated(routine)
            path.append(.connect)
        }
    }
}

// MARK: - Step 1: name and description

private struct RoutineDetailsStepView: View {
    @ObservedObject var viewModel: RoutineCreateViewModel
    let onNext: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, description
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    Text("Choose the notes your routine will use. Then connect your own code to turn them into something useful.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)

                    Text("1. Give it an assignment")
                        .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Name")
                            .font(.system(size: Theme.fontSizeSM, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        TextField("Weekly project brief", text: $viewModel.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.fontSizeMD))
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerRadiusSM)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .description }
                            .onChange(of: viewModel.name) { _, newValue in
                                let limited = RoutineLimits.limited(newValue, to: RoutineLimits.maxNameLength)
                                if limited != newValue { viewModel.name = limited }
                            }
                        if viewModel.name.unicodeScalars.count >= RoutineLimits.maxNameLength {
                            Text("Names can be up to \(RoutineLimits.maxNameLength) characters.")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Description (optional)")
                            .font(.system(size: Theme.fontSizeSM, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        TextField(
                            "Keep a short brief of confirmed decisions, open questions, and next steps.",
                            text: $viewModel.description,
                            axis: .vertical
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .lineLimit(4...8)
                        .focused($focusedField, equals: .description)
                        .onChange(of: viewModel.description) { _, newValue in
                            let limited = RoutineLimits.limited(newValue, to: RoutineLimits.maxDescriptionLength)
                            if limited != newValue { viewModel.description = limited }
                        }
                        Text("Describe what you want to maintain. Your runner supplies the instructions and does the work.")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textTertiary)
                    }

                    Button {
                        focusedField = nil
                        onNext()
                    } label: {
                        Text("Next: choose its notes")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.canContinueFromDetails))
                    .disabled(!viewModel.canContinueFromDetails)

                    Spacer(minLength: Theme.spacingXL)
                }
                .padding(Theme.spacingLG)
            }
        }
        .navigationTitle("Create a routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .foregroundColor(Theme.accent)
            }
        }
    }
}

// MARK: - Step 2: choose its notes

private struct RoutineChooseNotesStepView: View {
    @ObservedObject var viewModel: RoutineCreateViewModel
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    Toggle(isOn: $viewModel.selection.allNotes) {
                        Text("All my notes, including future notes")
                            .font(.system(size: Theme.fontSizeMD))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .tint(Theme.accent)
                } footer: {
                    Text("Choose a whole category to include all its notes and future additions, or select individual subcategories. Selections are combined.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)

                categorySections
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onNext) {
                Text("Next: check the notes")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.scope != nil))
            .disabled(viewModel.scope == nil)
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, Theme.spacingSM)
            .background(Theme.background)
        }
        .navigationTitle("Choose its notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadOptionsIfNeeded()
        }
    }

    @ViewBuilder
    private var categorySections: some View {
        if let options = viewModel.options {
            if options.categories.isEmpty {
                Section {
                    Text("No active categories yet. You can choose all your notes, or add categories in Settings first.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            } else {
                ForEach(options.categories) { category in
                    Section {
                        choiceRow(
                            title: "\(category.name) — entire category",
                            isOn: viewModel.selection.allNotes || viewModel.selection.categoryIDs.contains(category.categoryID),
                            isEnabled: !viewModel.selection.allNotes
                        ) {
                            viewModel.selection.toggleCategory(category.categoryID)
                        }

                        // Hidden while the whole category (or every note) is chosen, as on the web.
                        let subcategories = options.subcategories(of: category.categoryID)
                        ForEach(subcategories) { subcategory in
                            if viewModel.selection.canChooseSubcategory(subcategory) {
                                choiceRow(
                                    title: subcategory.name,
                                    isOn: viewModel.selection.subCategoryIDs.contains(subcategory.subCategoryID),
                                    isEnabled: true,
                                    indented: true
                                ) {
                                    viewModel.selection.toggleSubcategory(subcategory.subCategoryID)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        } else if let error = viewModel.optionsError {
            Section {
                Text(error)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(.red)
                Button("Reload categories") {
                    Task { await viewModel.loadOptions() }
                }
                .foregroundColor(Theme.accent)
            }
            .listRowBackground(Theme.surface)
        } else {
            Section {
                HStack(spacing: Theme.spacingSM) {
                    ProgressView()
                    Text("Loading your categories…")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .listRowBackground(Theme.surface)
        }
    }

    private func choiceRow(
        title: String,
        isOn: Bool,
        isEnabled: Bool,
        indented: Bool = false,
        toggle: @escaping () -> Void
    ) -> some View {
        Button(action: toggle) {
            HStack(spacing: Theme.spacingSMPlus) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? Theme.accent : Theme.textTertiary)
                Text(title)
                    .font(.system(size: indented ? Theme.fontSizeSM : Theme.fontSizeMD))
                    .foregroundColor(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                Spacer()
            }
            .padding(.leading, indented ? Theme.spacingLG : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Step 3: check the notes, then create

private struct RoutinePreviewStepView: View {
    @ObservedObject var viewModel: RoutineCreateViewModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                Section {
                    previewStatus
                } footer: {
                    Text("Preview shows up to 12 recent organized notes. New notes appear after processing. Zero matches is okay; future matching notes will be included.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)

                if case .ready(let preview) = viewModel.previewState, !preview.notes.isEmpty {
                    Section {
                        ForEach(preview.notes) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nonBlank(note.title) ?? "Untitled note")
                                    .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(nonBlank(note.preview) ?? "No readable text yet.")
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, Theme.spacingXS)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.spacingXS) {
                if let error = viewModel.createError {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    Task { await viewModel.create() }
                } label: {
                    Text(viewModel.isCreating ? "Creating…" : "Create routine")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.canCreate))
                .disabled(!viewModel.canCreate)
                Text("Next: get the connection details for your runner.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, Theme.spacingSM)
            .background(Theme.background)
        }
        .navigationTitle("Check the inputs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(viewModel.isCreating)
        .task(id: viewModel.scope) {
            await viewModel.loadPreview()
        }
    }

    @ViewBuilder
    private var previewStatus: some View {
        switch viewModel.previewState {
        case .idle:
            Text("Select categories or subcategories to preview their notes.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
        case .loading:
            HStack(spacing: Theme.spacingSM) {
                ProgressView()
                Text("Loading matching notes…")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
            }
        case .ready(let preview):
            Text(RoutinePreviewText.summary(preview))
                .font(.system(size: Theme.fontSizeMD, weight: .medium))
                .foregroundColor(Theme.textPrimary)
        case .failed(let message):
            Text(message)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(.red)
            Button("Retry preview") {
                Task { await viewModel.loadPreview() }
            }
            .foregroundColor(Theme.accent)
        }
    }

    private func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

#Preview {
    RoutineCreateFlowView { _ in }
}
