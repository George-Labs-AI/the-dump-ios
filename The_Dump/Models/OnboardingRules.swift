import Foundation

/// Why a card's edits can't be saved, one message per field.
struct OnboardingCardEditErrors: Equatable {
    var name: String?
    var names: String?

    var isEmpty: Bool { name == nil && names == nil }
}

/// The rules for onboarding's cards and the Finish save, kept apart from the
/// view model so they can be tested on their own
/// (docs/onboarding-voice-handoff.md, sections 2 and 6.1; D-023).
enum OnboardingRules {
    /// The `source` saved on each drafted category, and on the catch-all.
    static let cardSource = "onboarding_voice"
    static let catchAllSource = "onboarding_catchall"

    /// Names are compared ignoring case and surrounding spaces, as the
    /// server's category save does.
    static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Chips trimmed, blanks dropped, and repeats (ignoring case) removed,
    /// keeping the first spelling.
    static func cleanedChips(_ chips: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for chip in chips {
            let trimmed = chip.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    // MARK: - Screen 3

    /// "Got it. One quick one." or "Got it. Two quick ones."
    static func questionsHeadline(count: Int) -> String {
        count == 1 ? "Got it. One quick one." : "Got it. Two quick ones."
    }

    /// The check's "You covered …" line followed by " Anything else?".
    static func questionsBody(summary: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anything else?" : "\(trimmed) Anything else?"
    }

    /// The answers that count for revise mode: only ones actually given.
    static func answers(from followups: [OnboardingFollowup]) -> [OnboardingAnswer] {
        followups.compactMap { followup in
            guard followup.isAnswered, let answer = followup.answer else { return nil }
            return OnboardingAnswer(
                question: followup.question,
                answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // MARK: - Screens 4b to 4d

    /// What blocks a card's edits, shown under the field it is about (4d).
    /// The name field stops at the length limit, so "too long" only comes up
    /// for a name that was already longer.
    static func editErrors(
        name: String,
        names: [String],
        others: [String],
        catchAllName: String?,
        maxLength: Int
    ) -> OnboardingCardEditErrors {
        var errors = OnboardingCardEditErrors()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = nameKey(trimmed)
        if trimmed.isEmpty {
            errors.name = "Give it a name."
        } else if trimmed.count > maxLength {
            errors.name = "Keep the name to \(maxLength) characters."
        } else if let existing = others.first(where: { nameKey($0) == key }) {
            errors.name = "You already have a category called \(existing.trimmingCharacters(in: .whitespacesAndNewlines))."
        } else if let catchAllName, nameKey(catchAllName) == key {
            errors.name = "\(catchAllName) is added for you at the end."
        }
        if cleanedChips(names).isEmpty {
            errors.names = "Add at least one name so notes can find this category."
        }
        return errors
    }

    // MARK: - Finish

    /// Finish is open once there are enough cards, not too many, and every
    /// one is approved with at least one name.
    static func canFinish(cards: [OnboardingCard], rules: OnboardingCategoryRules) -> Bool {
        guard cards.count >= rules.min, cards.count <= rules.hardMax else { return false }
        return cards.allSatisfy { $0.approved && $0.canApprove }
    }

    /// The description that is saved: what the card is for, plus
    /// " Things like: a, b." when it has examples (decision 9).
    static func savedDefinition(description: String, examples: [String]) -> String {
        let base = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let chips = cleanedChips(examples)
        guard !chips.isEmpty else { return base }
        let things = "Things like: \(chips.joined(separator: ", "))."
        return base.isEmpty ? things : "\(base) \(things)"
    }

    /// Every approved card, then the catch-all, as one save. One request,
    /// because the server checks every name before writing any, so a clash
    /// saves nothing and the person can fix it and try again.
    static func finishPayload(cards: [OnboardingCard], catchAll: OnboardingCatchAll?) -> [Category] {
        var payload = cards.map { card in
            Category(
                name: card.name.trimmingCharacters(in: .whitespacesAndNewlines),
                definition: savedDefinition(description: card.description, examples: card.examples),
                keywords: cleanedChips(card.names),
                source: cardSource
            )
        }
        if let catchAll {
            payload.append(Category(
                name: catchAll.name,
                definition: catchAll.description,
                keywords: [],
                source: catchAllSource
            ))
        }
        return payload
    }

    /// The category a 409 from the save is about. The server's messages
    /// quote the existing name (`You already have a category called "X".`),
    /// so the first quoted name is matched against the cards.
    static func clashingName(in message: String) -> String? {
        let parts = message.components(separatedBy: "\"")
        guard parts.count >= 3 else { return nil }
        let name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
