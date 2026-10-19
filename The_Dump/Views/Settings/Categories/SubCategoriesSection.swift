import SwiftUI

/// The Sub-categories part of a category's Settings screen: each active
/// sub-category with its note count (tap to edit or delete; touch and hold
/// for Edit and Delete, the web's row buttons), then an Archived group with
/// Restore. Hidden when the server doesn't offer these routes yet.
struct SubCategoriesSection: View {
    private struct ActionError {
        let title: String
        let message: String
    }

    @StateObject private var viewModel: SubCategoryManagementViewModel
    @State private var editing: SubCategoryItem?
    @State private var deleting: SubCategoryItem?
    @State private var actionError: ActionError?

    /// `onChanged` runs after every saved change, so the category list can
    /// refresh its sub-category counts.
    init(categoryId: Int, onChanged: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SubCategoryManagementViewModel(
            categoryId: categoryId,
            onChange: onChanged
        ))
    }

    /// For previews: a view model with its own stand-in server.
    init(viewModel: SubCategoryManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            if viewModel.loadState != .unavailable {
                content
            }
        }
        .task { await viewModel.load() }
        .navigationDestination(item: $editing) { item in
            SubCategoryDetailView(viewModel: viewModel, subCatId: item.subCatId)
        }
        .alert(SubCategoryWording.deleteButton, isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        ), presenting: deleting) { item in
            Button("Cancel", role: .cancel) {}
            Button(SubCategoryWording.deleteButton, role: .destructive) {
                Task {
                    if let message = await viewModel.delete(item) {
                        actionError = ActionError(title: "Couldn't delete", message: message)
                    }
                }
            }
        } message: { item in
            Text(SubCategoryWording.deleteMessage(for: item))
        }
        .alert(actionError?.title ?? "", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError?.message ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        Text(SubCategoryWording.sectionTitle)
            .sectionLabel()
            .foregroundColor(Theme.textSecondary)
            .padding(.top, Theme.spacingMD)

        switch viewModel.loadState {
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(Theme.spacingMD)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(message)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                .foregroundColor(Theme.accent)
            }
            .padding(Theme.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadiusSM)
        case .loaded, .unavailable:
            loadedList
        }
    }

    @ViewBuilder
    private var loadedList: some View {
        if viewModel.active.isEmpty {
            Text(SubCategoryWording.emptyList)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
                .padding(Theme.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .cornerRadius(Theme.cornerRadiusSM)
        } else {
            rows(viewModel.active) { item in
                Button {
                    editing = item
                } label: {
                    ActiveSubCategoryRow(item: item)
                }
                .disabled(viewModel.isBusy(item))
                .contextMenu {
                    Button("Edit") { editing = item }
                    Button("Delete", role: .destructive) { deleting = item }
                }
            }
        }

        if !viewModel.archived.isEmpty {
            Text(SubCategoryWording.archivedTitle)
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
                .padding(.top, Theme.spacingSM)

            rows(viewModel.archived) { item in
                ArchivedSubCategoryRow(item: item, isBusy: viewModel.isBusy(item)) {
                    Task {
                        if let message = await viewModel.restore(item) {
                            actionError = ActionError(title: "Couldn't restore", message: message)
                        }
                    }
                }
            }
        }
    }

    private func rows<Row: View>(
        _ items: [SubCategoryItem],
        @ViewBuilder row: @escaping (SubCategoryItem) -> Row
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                        .padding(.leading, Theme.spacingMD)
                }
                row(item)
            }
        }
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadiusSM)
    }
}

// MARK: - Rows

private struct ActiveSubCategoryRow: View {
    let item: SubCategoryItem

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: Theme.fontSizeMD))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(SubCategoryWording.noteCount(item.noteCount))
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, Theme.spacingSMPlus)
        .contentShape(Rectangle())
    }
}

private struct ArchivedSubCategoryRow: View {
    let item: SubCategoryItem
    let isBusy: Bool
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            Text(item.name)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            if isBusy {
                ProgressView()
            } else {
                Button(SubCategoryWording.restoreButton, action: onRestore)
                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, Theme.spacingSMPlus)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScrollView {
            SubCategoriesSection(viewModel: SubCategoryManagementViewModel(
                categoryId: 1,
                client: .preview
            ))
            .padding(Theme.spacingLG)
        }
        .background(Theme.background)
    }
}
#endif
