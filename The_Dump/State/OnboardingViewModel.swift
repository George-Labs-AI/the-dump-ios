import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Mode
    let isSettingsMode: Bool

    // MARK: - Screen 1 State
    @Published var selectedPresetId: String?

    // MARK: - Screen 2 State
    @Published var categoryInput: String = ""
    @Published var categories: [OnboardingCategory] = []
    @Published var activeDomains: Set<String> = []
    @Published private(set) var existingCategoryNames: Set<String> = []

    // MARK: - Loading/Error State
    @Published private(set) var isSubmitting: Bool = false
    @Published var errorMessage: String?

    // MARK: - Init

    init(isSettingsMode: Bool = false) {
        self.isSettingsMode = isSettingsMode
    }

    // MARK: - Settings Mode Support

    func loadExistingCategories(_ names: [String]) {
        existingCategoryNames = Set(names.map { $0.lowercased() })
    }

    // MARK: - Computed Properties

    var categoryCount: Int {
        categories.count
    }

    var isCategoryCountValid: Bool {
        if isSettingsMode {
            return categoryCount >= 1
        }
        return categoryCount >= 3 && categoryCount <= 10
    }

    var categoriesNeededMessage: String {
        if isSettingsMode {
            if categoryCount == 0 {
                return "Add at least 1 category to continue"
            } else {
                return "Add more categories or continue"
            }
        }
        if categoryCount < 3 {
            let needed = 3 - categoryCount
            return "Add \(needed) more \(needed == 1 ? "category" : "categories") to continue"
        } else if categoryCount > 10 {
            return "Maximum 10 categories allowed"
        } else {
            return "You can always add or change categories later"
        }
    }

    var selectedPreset: OnboardingPreset? {
        OnboardingPresets.allPresets.first { $0.id == selectedPresetId }
    }

    var availableSuggestions: [String] {
        guard !activeDomains.isEmpty else { return [] }

        let newCategoryNames = Set(categories.map { $0.name.lowercased() })
        let allExistingNames = newCategoryNames.union(existingCategoryNames)

        return DomainSuggestions.allDomains
            .filter { activeDomains.contains($0.id) }
            .flatMap { $0.suggestions }
            .filter { !allExistingNames.contains($0.lowercased()) }
    }

    // MARK: - Screen 1 Actions

    func selectPreset(_ preset: OnboardingPreset) {
        selectedPresetId = preset.id
    }

    func isPresetSelected(_ preset: OnboardingPreset) -> Bool {
        selectedPresetId == preset.id
    }

    // MARK: - Screen 2 Actions

    func addCategoryFromInput() {
        addCategory(name: categoryInput)
    }

    func addCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= 30 else { return }
        guard !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        guard !existingCategoryNames.contains(trimmed.lowercased()) else { return }
        guard categories.count < 10 else { return }

        categories.append(OnboardingCategory(name: trimmed))
        categoryInput = ""
    }

    func removeCategory(_ category: OnboardingCategory) {
        categories.removeAll { $0.id == category.id }
    }

    func toggleDomain(_ domainId: String) {
        if activeDomains.contains(domainId) {
            activeDomains.remove(domainId)
        } else {
            activeDomains.insert(domainId)
        }
    }

    func isDomainActive(_ domainId: String) -> Bool {
        activeDomains.contains(domainId)
    }

    func addSuggestion(_ suggestion: String) {
        addCategory(name: suggestion)
    }

    // MARK: - Screen 3 Actions

    func updateDefinition(for categoryId: UUID, definition: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[index].definition = definition
    }

    func updateKeywords(for categoryId: UUID, keywords: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[index].keywords = keywords
    }

    // MARK: - Submit Actions

    func submitPreset(appState: AppState) async -> Bool {
        guard let preset = selectedPreset, !preset.isCustomOption else { return false }
        return await submitCategories(preset.categories, appState: appState)
    }

    func submitCustomCategories(appState: AppState) async -> Bool {
        return await submitCategories(categories, appState: appState)
    }

    func skipDefinitions(appState: AppState) async -> Bool {
        let strippedCategories = categories.map {
            OnboardingCategory(name: $0.name, definition: "", keywords: "")
        }
        return await submitCategories(strippedCategories, appState: appState)
    }

    // MARK: - Private

    private func submitCategories(_ onboardingCategories: [OnboardingCategory], appState: AppState?) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil

        let apiCategories = onboardingCategories.map { $0.toAPICategory() }

        do {
            let response = try await NotesService.shared.addCategories(apiCategories)
#if DEBUG
            print("[OnboardingViewModel] Categories saved: \(response.updatedCount) categories")
            for cat in response.categories {
                print("[OnboardingViewModel]   - \(cat.name) (id=\(cat.categoryId))")
            }
#endif
            if !isSettingsMode {
                appState?.markOnboardingComplete()
            }
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
#if DEBUG
            print("[OnboardingViewModel] Failed to save categories: \(error)")
#endif
            isSubmitting = false
            return false
        }
    }

    // MARK: - Settings Mode Submit

    func submitNewCategories() async -> Bool {
        return await submitCategories(categories, appState: nil)
    }

    func skipDefinitionsFromSettings() async -> Bool {
        let strippedCategories = categories.map {
            OnboardingCategory(name: $0.name, definition: "", keywords: "")
        }
        return await submitCategories(strippedCategories, appState: nil)
    }
}
