import Foundation

// MARK: - Onboarding Category (internal model for onboarding flow)

struct OnboardingCategory: Identifiable, Equatable {
    let id: UUID
    var name: String
    var definition: String
    var keywords: String

    init(name: String, definition: String = "", keywords: String = "") {
        self.id = UUID()
        self.name = name
        self.definition = definition
        self.keywords = keywords
    }

    func toAPICategory() -> Category {
        let keywordArray = keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Category(
            name: name,
            definition: definition.isEmpty ? nil : definition,
            keywords: keywordArray.isEmpty ? nil : keywordArray,
            source: "onboarding"
        )
    }
}

// MARK: - Preset Definition

struct OnboardingPreset: Identifiable {
    let id: String
    let title: String
    let previewText: String
    let icon: String
    let categories: [OnboardingCategory]
    let isCustomOption: Bool

    init(id: String, title: String, previewText: String, icon: String, categories: [OnboardingCategory], isCustomOption: Bool = false) {
        self.id = id
        self.title = title
        self.previewText = previewText
        self.icon = icon
        self.categories = categories
        self.isCustomOption = isCustomOption
    }
}

// MARK: - Preset Data

enum OnboardingPresets {

    static let contentCreator = OnboardingPreset(
        id: "content_creator",
        title: "Content Creator",
        previewText: "Content Ideas \u{00B7} Business \u{00B7} Inspiration \u{00B7} Personal",
        icon: "video.fill",
        categories: [
            OnboardingCategory(
                name: "Content Ideas",
                definition: "Ideas for content you want to create, including blog posts, videos, social media, podcasts, newsletters, and other media",
                keywords: "post, video, idea, topic, draft, hook, script, thumbnail, series, viral, trending, episode"
            ),
            OnboardingCategory(
                name: "Business",
                definition: "Business and career-related notes including strategy, revenue, partnerships, clients, and professional development",
                keywords: "client, revenue, strategy, deal, contract, pitch, meeting, sponsor, brand, collab, rate, income"
            ),
            OnboardingCategory(
                name: "Inspiration",
                definition: "Content from others that inspires you, references to revisit, quotes, examples, and creative fuel",
                keywords: "reference, example, inspiration, bookmark, save, love, style, aesthetic, vibe, remix, like"
            ),
            OnboardingCategory(
                name: "Personal",
                definition: "Personal life notes not related to content creation or business",
                keywords: "personal, life, family, home, health, self, journal, thought, feeling, plan"
            )
        ]
    )

    static let entrepreneur = OnboardingPreset(
        id: "entrepreneur",
        title: "Entrepreneur",
        previewText: "Business Ideas \u{00B7} Marketing/Content \u{00B7} Operations \u{00B7} Personal",
        icon: "briefcase.fill",
        categories: [
            OnboardingCategory(
                name: "Business Ideas",
                definition: "New business ideas, startup concepts, product opportunities, and ventures to explore",
                keywords: "idea, startup, opportunity, market, concept, pivot, venture, launch, MVP, validate, problem, solution"
            ),
            OnboardingCategory(
                name: "Marketing/Content",
                definition: "Marketing strategies, content for your business, social media, ads, PR, and customer communications",
                keywords: "marketing, content, post, ad, campaign, social, email, launch, announcement, PR, brand, audience"
            ),
            OnboardingCategory(
                name: "Operations",
                definition: "Day-to-day business operations, processes, tools, team management, and logistics",
                keywords: "process, tool, system, team, hire, vendor, workflow, automation, ops, admin, setup, integrate"
            ),
            OnboardingCategory(
                name: "Personal",
                definition: "Personal life notes not related to your business",
                keywords: "personal, life, family, home, health, self, journal, thought, feeling, plan"
            )
        ]
    )

    static let lifeAndWork = OnboardingPreset(
        id: "life_and_work",
        title: "Life + Work",
        previewText: "Work \u{00B7} Health \u{00B7} Home \u{00B7} Family \u{00B7} Finances \u{00B7} Ideas",
        icon: "heart.fill",
        categories: [
            OnboardingCategory(
                name: "Work",
                definition: "Job and career-related notes, projects, meetings, tasks, and professional development",
                keywords: "work, job, meeting, project, boss, team, deadline, task, career, promotion, salary, office"
            ),
            OnboardingCategory(
                name: "Health",
                definition: "Physical and mental health, fitness, medical appointments, nutrition, and wellness",
                keywords: "health, doctor, workout, gym, medication, symptom, sleep, diet, exercise, therapy, appointment, weight"
            ),
            OnboardingCategory(
                name: "Home",
                definition: "Home management, maintenance, repairs, renovation projects, and household tasks",
                keywords: "home, house, repair, fix, clean, renovation, furniture, decor, organize, maintenance, contractor, room"
            ),
            OnboardingCategory(
                name: "Family",
                definition: "Family-related notes, kids, events, activities, and family planning",
                keywords: "family, kids, school, birthday, vacation, event, mom, dad, parent, activity, childcare, relative"
            ),
            OnboardingCategory(
                name: "Finances",
                definition: "Personal finance, budgeting, bills, investments, taxes, and money management",
                keywords: "money, budget, bill, payment, tax, invest, savings, expense, income, account, debt, retirement"
            ),
            OnboardingCategory(
                name: "Ideas",
                definition: "Random ideas, thoughts to capture, things to explore later, and notes to self",
                keywords: "idea, thought, random, someday, maybe, explore, research, remember, note, interesting, look into"
            )
        ]
    )

    static let customOption = OnboardingPreset(
        id: "custom",
        title: "Add custom categories",
        previewText: "Choose your own categories",
        icon: "plus.circle.fill",
        categories: [],
        isCustomOption: true
    )

    static let allPresets: [OnboardingPreset] = [
        contentCreator,
        entrepreneur,
        lifeAndWork,
        customOption
    ]
}

// MARK: - Domain Suggestions for Screen 2

struct DomainSuggestion: Identifiable {
    let id: String
    let name: String
    let suggestions: [String]
}

enum DomainSuggestions {
    static let work = DomainSuggestion(
        id: "work",
        name: "Work",
        suggestions: ["Active Projects", "Client Work", "Meetings", "Team Notes", "Strategy", "Finance"]
    )

    static let home = DomainSuggestion(
        id: "home",
        name: "Home",
        suggestions: ["Home Maintenance", "Renovations", "Decor Ideas", "Organization", "Shopping Lists"]
    )

    static let family = DomainSuggestion(
        id: "family",
        name: "Family",
        suggestions: ["Kids Activities", "Family Events", "Meal Planning", "Health Records", "Vacation Planning"]
    )

    static let personalProjects = DomainSuggestion(
        id: "personal",
        name: "Personal Projects",
        suggestions: ["Side Projects", "Hobbies", "Learning", "Goals", "Creative Work"]
    )

    static let ideasAndWriting = DomainSuggestion(
        id: "ideas",
        name: "Ideas and Writing",
        suggestions: ["Blog Posts", "Substack Research", "Writing My Book", "Tik Tok", "Notes to Self"]
    )

    static let health = DomainSuggestion(
        id: "health",
        name: "Health",
        suggestions: ["Fitness", "Medical", "Nutrition", "Mental Health", "Wellness Goals"]
    )

    static let allDomains: [DomainSuggestion] = [
        work,
        home,
        family,
        personalProjects,
        ideasAndWriting,
        health
    ]
}
