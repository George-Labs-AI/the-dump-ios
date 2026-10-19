import SwiftUI

/// Edit one sub-category's name, description and keywords, or delete it
/// (which archives it; it can be restored from the category's screen). A
/// rename also changes the name on every note that has it.
struct SubCategoryDetailView: View {
    @ObservedObject var viewModel: SubCategoryManagementViewModel
    let subCatId: Int

    @Environment(\.dismiss) private var dismiss

    @State private var draft: SubCategoryEditDraft?
    @State private var saveError: String?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, description, keywords
    }

    init(viewModel: SubCategoryManagementViewModel, subCatId: Int) {
        self.viewModel = viewModel
        self.subCatId = subCatId
        _draft = State(initialValue: viewModel.item(withID: subCatId).map { SubCategoryEditDraft($0) })
    }

    private var item: SubCategoryItem? {
        viewModel.item(withID: subCatId)
    }

    private var isBusy: Bool {
        item.map { viewModel.isBusy($0) } ?? false
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let draft {
                editor(draft)
            } else {
                Text("This sub-category is no longer available.")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
                    .padding()
            }
        }
        .navigationTitle(SubCategoryWording.editTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isBusy {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .foregroundColor(canSave ? Theme.accent : Theme.textTertiary)
                    .disabled(!canSave)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .foregroundColor(Theme.accent)
            }
        }
        .alert(SubCategoryWording.deleteButton, isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(SubCategoryWording.deleteButton, role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text(item.map { SubCategoryWording.deleteMessage(for: $0) } ?? "")
        }
        .alert("Couldn't delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Editor

    private func editor(_ current: SubCategoryEditDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                Text(SubCategoryWording.noteCount(item?.noteCount ?? current.original.noteCount))
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    fieldLabel("Name")
                    TextField("Name", text: binding(\.name))
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .name)
                        .onChange(of: current.name) { _, newValue in
                            // Only trim what the user types, so an older,
                            // longer name isn't silently edited on load.
                            guard focusedField == .name else { return }
                            let limited = CategoryLimits.limitedName(newValue)
                            if limited != newValue { draft?.name = limited }
                        }

                    if CategoryLimits.isNameAtLimit(current.name) {
                        Text(SubCategoryWording.nameTooLong(CategoryLimits.maxNameLength))
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textTertiary)
                    }

                    if let clash = current.nameClash(among: viewModel.all) {
                        Text(clash)
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    fieldLabel("Description")
                    TextField("What kind of notes belong here?", text: binding(\.description), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .description)
                }

                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    fieldLabel("Keywords")
                    TextField("comma, separated, keywords", text: binding(\.keywordsText))
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .keywords)
                }

                Text(SubCategoryWording.renameHelp)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let saveError {
                    Text(saveError)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text("Danger zone")
                        .sectionLabel()
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, Theme.spacingMD)

                    Button {
                        focusedField = nil
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(SubCategoryWording.deleteButton)
                            Spacer()
                        }
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(.red)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                    }
                    .disabled(isBusy)
                }

                Spacer(minLength: Theme.spacingXL)
            }
            .padding(Theme.spacingLG)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.fontSizeSM, weight: .medium))
            .foregroundColor(Theme.textPrimary)
    }

    private func binding(_ keyPath: WritableKeyPath<SubCategoryEditDraft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { newValue in
                draft?[keyPath: keyPath] = newValue
                saveError = nil
            }
        )
    }

    // MARK: - Actions

    private var canSave: Bool {
        guard let draft, !isBusy else { return false }
        return draft.canSave(among: viewModel.all)
    }

    private func save() async {
        guard let draft else { return }
        focusedField = nil
        saveError = nil
        if let message = await viewModel.save(draft) {
            saveError = message
        } else {
            dismiss()
        }
    }

    private func delete() async {
        guard let item else { return }
        if let message = await viewModel.delete(item) {
            deleteError = message
        } else {
            dismiss()
        }
    }
}
