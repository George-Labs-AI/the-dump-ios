import XCTest
@testable import The_Dump

/// The note screen's edit rules: a note always keeps a category, a move
/// drops sub-categories the new category lacks, at most 3 sub-categories,
/// and only what the user changed is sent to /api/edit_note.
@MainActor
final class NoteEditDraftTests: XCTestCase {
    private let types = NoteTypeCatalog.builtIn

    private let options = NoteEditOptions(
        categories: [
            NoteCategoryChoice(id: 216, name: "Work", label: "Work"),
            NoteCategoryChoice(id: 217, name: "Personal", label: "Personal"),
            NoteCategoryChoice(id: 218, name: "Recipes", label: "Recipes"),
        ],
        subCategoriesByCategory: [
            "work": ["meetings", "project ideas"],
            "personal": ["finances", "health", "meetings"],
            "recipes": ["desserts", "dinners"],
        ]
    )

    private func workNote(subCategories: [String] = ["Meetings", "project ideas"], type: String = "Log") -> NoteEditDraft {
        NoteEditDraft(
            title: "Standup",
            content: "Notes from standup",
            categoryId: 216,
            categoryName: "Work",
            subCategories: subCategories,
            noteType: type,
            noteTypes: types
        )
    }

    private func choice(_ id: Int) -> NoteCategoryChoice {
        options.category(withID: id)!
    }

    private func move(_ draft: inout NoteEditDraft, to id: Int) {
        let target = choice(id)
        draft.selectCategory(target, availableSubCategories: options.subCategories(forCategoryNamed: target.name))
    }

    /// The JSON body editNote would send for these changes.
    private func body(_ changes: NoteEditChanges) throws -> [String: Any] {
        let request = try NotesService.editNoteBody(
            noteId: "n1",
            entries: changes.entries,
            title: changes.title,
            categoryId: changes.categoryId,
            subCategories: changes.subCategories,
            type: changes.type
        )
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Nothing changed

    func testUntouchedDraftSendsNothing() {
        let draft = workNote()
        XCTAssertFalse(draft.hasChanges)
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.changes.isEmpty)
    }

    // MARK: - Title and content

    func testTitleEditSendsOnlyTheTitle() throws {
        var draft = workNote()
        draft.title = "  Weekly standup  "
        XCTAssertTrue(draft.canSave)
        XCTAssertEqual(draft.changes, NoteEditChanges(title: "Weekly standup"))

        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "title"])
        XCTAssertEqual(json["title"] as? String, "Weekly standup")
    }

    func testContentEditSendsOnlyTheContent() throws {
        var draft = workNote()
        draft.content = "Notes from standup\n\n- ship it"
        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "entries"])
        XCTAssertEqual(json["entries"] as? String, "Notes from standup\n\n- ship it")
    }

    func testWhitespaceOnlyEditsAreNotChanges() {
        var draft = workNote()
        draft.title = "Standup "
        draft.content = "Notes from standup\n"
        XCTAssertFalse(draft.hasChanges)
    }

    func testBlankTitleCannotBeSaved() {
        var draft = workNote()
        draft.title = "   "
        XCTAssertFalse(draft.isTitleValid)
        XCTAssertFalse(draft.canSave)
    }

    // MARK: - Category

    func testMoveKeepsOnlySubCategoriesTheNewCategoryHas() throws {
        var draft = workNote()
        move(&draft, to: 217)
        // "Meetings" exists in Personal too (matched ignoring case);
        // "project ideas" does not.
        XCTAssertEqual(draft.subCategories, ["Meetings"])
        XCTAssertTrue(draft.categoryChanged)

        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "category_id", "sub_categories"])
        XCTAssertEqual(json["category_id"] as? Int, 217)
        XCTAssertEqual(json["sub_categories"] as? [String], ["Meetings"])
    }

    func testMoveAlwaysSendsSubCategoriesEvenWhenNoneAreLeft() throws {
        // A move that leaves the key out clears them on the server anyway,
        // but sending [] says so explicitly.
        var draft = workNote()
        move(&draft, to: 218)
        XCTAssertEqual(draft.subCategories, [])

        let json = try body(draft.changes)
        XCTAssertEqual(json["category_id"] as? Int, 218)
        XCTAssertEqual(json["sub_categories"] as? [String], [])
    }

    func testGoingBackToTheNotesCategoryRestoresItsSubCategories() {
        var draft = workNote()
        move(&draft, to: 218)
        move(&draft, to: 216)
        XCTAssertEqual(draft.subCategories, ["Meetings", "project ideas"])
        XCTAssertFalse(draft.hasChanges)
        XCTAssertTrue(draft.changes.isEmpty)
    }

    func testSelectingTheSameCategoryChangesNothing() {
        var draft = workNote()
        move(&draft, to: 216)
        XCTAssertEqual(draft.subCategories, ["Meetings", "project ideas"])
        XCTAssertFalse(draft.categoryChanged)
    }

    func testArchivedCategoryIsShownAndKeptOnATextEdit() throws {
        var draft = NoteEditDraft(
            title: "Old", content: "Body", categoryId: 99, categoryName: "Old projects",
            subCategories: ["archive"], noteType: "Log", noteTypes: types
        )
        let choices = draft.categoryChoices(from: options)
        XCTAssertEqual(choices.first, NoteCategoryChoice(id: 99, name: "Old projects", label: "Old projects (archived)"))
        XCTAssertEqual(choices.count, 4)
        // Its own sub-category stays pickable although the map doesn't list it.
        XCTAssertEqual(draft.subCategoryChoices(from: options), ["archive"])

        draft.content = "Body, edited"
        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "entries"])
    }

    func testActiveCategoryIsNotListedTwice() {
        let choices = workNote().categoryChoices(from: options)
        XCTAssertEqual(choices.map(\.id), [216, 217, 218])
    }

    func testBeforeCategoriesLoadOnlyTheNotesOwnIsShownAndNotCalledArchived() {
        let choices = workNote().categoryChoices(from: .empty)
        XCTAssertEqual(choices, [NoteCategoryChoice(id: 216, name: "Work", label: "Work")])
    }

    func testCategoryNameWithoutIDAdoptsTheActiveCategory() {
        var draft = NoteEditDraft(
            title: "T", content: "C", categoryId: nil, categoryName: "work",
            subCategories: [], noteType: "Log", noteTypes: types
        )
        draft.adoptCategoryID(from: options)
        XCTAssertEqual(draft.categoryId, 216)
        XCTAssertFalse(draft.categoryChanged)
        XCTAssertEqual(draft.categoryChoices(from: options).map(\.id), [216, 217, 218])
        XCTAssertEqual(draft.subCategoryChoices(from: options), ["meetings", "project ideas"])
    }

    func testNoteWithNoCategoryNeverSendsABlankOne() throws {
        var draft = NoteEditDraft(title: "T", content: "C", noteType: "Log", noteTypes: types)
        draft.adoptCategoryID(from: options)
        XCTAssertEqual(draft.categoryChoices(from: options).first?.label, "No category")
        XCTAssertNil(draft.changes.categoryId)

        move(&draft, to: 217)
        let json = try body(draft.changes)
        XCTAssertEqual(json["category_id"] as? Int, 217)
    }

    // MARK: - Sub-categories

    func testAtMostThreeSubCategories() throws {
        var draft = NoteEditDraft(
            title: "T", content: "C", categoryId: 217, categoryName: "Personal",
            subCategories: [], noteType: "Log", noteTypes: types
        )
        XCTAssertTrue(draft.toggleSubCategory("finances"))
        XCTAssertTrue(draft.toggleSubCategory("health"))
        XCTAssertTrue(draft.toggleSubCategory("meetings"))
        XCTAssertFalse(draft.canAddSubCategory)
        XCTAssertFalse(draft.toggleSubCategory("fourth"))
        XCTAssertEqual(draft.subCategories, ["finances", "health", "meetings"])

        // Deselecting frees a slot.
        XCTAssertTrue(draft.toggleSubCategory("Health"))
        XCTAssertTrue(draft.canAddSubCategory)

        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "sub_categories"])
        XCTAssertEqual(json["sub_categories"] as? [String], ["finances", "meetings"])
    }

    func testClearingAllSubCategoriesSendsAnEmptyList() throws {
        var draft = workNote()
        draft.toggleSubCategory("meetings")
        draft.toggleSubCategory("Project Ideas")
        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "sub_categories"])
        XCTAssertEqual(json["sub_categories"] as? [String], [])
    }

    func testReselectingTheSameSubCategoriesIsNotAChange() {
        var draft = workNote()
        draft.toggleSubCategory("Meetings")
        draft.toggleSubCategory("meetings")
        XCTAssertFalse(draft.subCategoriesChanged)
        XCTAssertTrue(draft.changes.isEmpty)
    }

    func testEditNoteBodyRefusesMoreThanThreeSubCategories() {
        XCTAssertThrowsError(try NotesService.editNoteBody(noteId: "n1", subCategories: ["a", "b", "c", "d"]))
    }

    func testEditNoteBodyRefusesAnEmptyEdit() {
        XCTAssertThrowsError(try NotesService.editNoteBody(noteId: "n1"))
    }

    // MARK: - Type

    func testTypeChangeSendsOnlyTheType() throws {
        var draft = workNote()
        draft.noteType = "Reminder"
        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "type"])
        XCTAssertEqual(json["type"] as? String, "Reminder")
    }

    func testSavedTypeMatchesTheListIgnoringCase() {
        let draft = workNote(type: "shopping list")
        XCTAssertEqual(draft.noteType, "Shopping List")
        XCTAssertEqual(draft.typeChoices(from: types).count, 17)
        XCTAssertFalse(draft.typeChanged)
    }

    func testOldTypeIsShownAndKeptUnlessChanged() throws {
        var draft = workNote(type: "Meeting Notes")
        let choices = draft.typeChoices(from: types)
        XCTAssertEqual(choices.first, NoteTypeChoice(value: "Meeting Notes", label: "Meeting Notes"))
        XCTAssertEqual(choices.count, 18)

        // The server would refuse "Meeting Notes", so a text edit must not send it.
        draft.title = "Renamed"
        XCTAssertNil(draft.changes.type)

        draft.noteType = "Log"
        XCTAssertEqual(try body(draft.changes)["type"] as? String, "Log")
    }

    func testNoteWithoutATypeOffersNoTypeAndSendsNothingForIt() {
        var draft = workNote(type: "")
        XCTAssertEqual(draft.typeChoices(from: types).first, NoteTypeChoice(value: "", label: "No type"))
        draft.title = "Renamed"
        XCTAssertNil(draft.changes.type)
    }

    // MARK: - Everything together

    func testCombinedEditSendsEachChangedField() throws {
        var draft = workNote()
        draft.title = "Retro"
        move(&draft, to: 217)
        draft.toggleSubCategory("health")
        draft.noteType = "Reflection"

        let json = try body(draft.changes)
        XCTAssertEqual(Set(json.keys), ["note_id", "title", "category_id", "sub_categories", "type"])
        XCTAssertEqual(json["note_id"] as? String, "n1")
        XCTAssertEqual(json["category_id"] as? Int, 217)
        XCTAssertEqual(json["sub_categories"] as? [String], ["Meetings", "health"])
        XCTAssertEqual(json["type"] as? String, "Reflection")
    }

    // MARK: - Options from the server

    func testOptionsFromServerResponses() throws {
        let categories = try JSONDecoder().decode(FetchCategoriesResponse.self, from: Data("""
        {"categories": [
          {"archived": false, "archived_at": null, "category_id": 217,
           "date_added": "2026-05-20T17:11:22.378844", "definition": "Personal life",
           "keywords": [], "last_modified_date": "2026-09-23T14:10:11.376938",
           "name": "Personal", "source": "user"},
          {"archived": false, "archived_at": null, "category_id": 216,
           "date_added": "2026-05-20T17:11:22.378844", "definition": "Job notes",
           "keywords": [], "last_modified_date": "2026-09-30T18:00:37.485859",
           "name": "Work", "source": "user"}
        ]}
        """.utf8))
        let map = try JSONDecoder().decode(CategoryMapResponse.self, from: Data("""
        {"categories": ["personal", "work"],
         "subcategories_by_category": {"personal": ["finances", "health"], "work": ["meetings"]}}
        """.utf8))

        let built = NoteEditOptions(categories: categories.categories, map: map)
        XCTAssertEqual(built.categories.map(\.id), [217, 216])
        XCTAssertEqual(built.categories.map(\.label), ["Personal", "Work"])
        XCTAssertEqual(built.subCategories(forCategoryNamed: " Personal "), ["finances", "health"])
        XCTAssertEqual(built.subCategories(forCategoryNamed: "Recipes"), [])

        let noMap = NoteEditOptions(categories: categories.categories, map: nil)
        XCTAssertEqual(noMap.subCategories(forCategoryNamed: "Work"), [])
    }

    func testCategoryMapDecodesWithFieldsMissing() throws {
        let map = try JSONDecoder().decode(CategoryMapResponse.self, from: Data("{}".utf8))
        XCTAssertNil(map.categories)
        XCTAssertNil(map.subcategoriesByCategory)
    }
}
