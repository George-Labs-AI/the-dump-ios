# Design System Audit — The Dump iOS

## Purpose
This document captures the complete findings from a 4-perspective audit (UX Designer, Front-End Engineer, Researcher, Devil's Advocate) of the current iOS codebase, comparing it against the new design system defined in `design-system.md`. It identifies gaps, architectural considerations, risks, and a phased implementation plan.

---

## CURRENT CODEBASE OVERVIEW

### Project Structure
```
The_Dump/
├── TheDumpApp.swift              # App entry point — forces .preferredColorScheme(.dark)
├── Theme.swift                   # CENTRAL STYLING FILE (~100 lines)
├── Assets.xcassets/              # Minimal — only AppIcon, empty AccentColor
├── Constants/
│   └── OnboardingPresets.swift
├── Models/
│   ├── APIError.swift
│   ├── NoteModels.swift
│   ├── SessionItem.swift
│   └── UploadResponse.swift
├── Services/
│   ├── AudioPlayerService.swift
│   ├── AudioRecorderService.swift
│   ├── AuthService.swift
│   ├── NotesService.swift
│   └── UploadService.swift
├── State/
│   ├── AppState.swift
│   ├── BrowseViewModel.swift
│   ├── NoteDetailViewModel.swift
│   ├── NotesListViewModel.swift
│   ├── OnboardingViewModel.swift
│   └── SessionStore.swift
└── Views/
    ├── Onboarding/
    │   ├── OnboardingCategoriesView.swift
    │   ├── OnboardingDefinitionsView.swift
    │   ├── OnboardingStartingPointView.swift
    │   └── OnboardingView.swift
    ├── Settings/
    │   ├── CategoryManagementView.swift
    │   └── SettingsCategoryFlowView.swift
    ├── AddSubCategoryView.swift
    ├── AuthStatusFooter.swift
    ├── AuthView.swift
    ├── BrowseFolderDestinationView.swift
    ├── BrowseView.swift
    ├── CameraView.swift
    ├── ContentView.swift          # "Dump" screen (capture)
    ├── MainTabView.swift          # Standard TabView with Dump + Browse
    ├── NoteDetailView.swift
    ├── NotesListView.swift
    ├── SettingsView.swift
    ├── TextNoteView.swift
    └── VoiceMemoView.swift
```

**Total**: ~6,300 lines of Swift, 18 view files.

### Current Theme.swift (Complete Contents)

```swift
enum Theme {
    // Colors (all dark-mode specific hex values)
    static let background = Color(hex: "0d0d0d")      // Near black
    static let darkGray = Color(hex: "1c1c1e")        // Cards/surfaces
    static let mediumGray = Color(hex: "2c2c2e")      // Medium surfaces
    static let lightGray = Color(hex: "3a3a3c")       // Lighter surfaces
    static let textPrimary = Color(hex: "f2f2f2")     // White text
    static let textSecondary = Color(hex: "a0a0a0")   // Gray text
    static let accent = Color(hex: "ff2d55")          // Pink/red accent
    static let accentHover = Color(hex: "e6254d")     // Darker accent for press

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // Font Sizes
    static let fontSizeXS: CGFloat = 12
    static let fontSizeSM: CGFloat = 14
    static let fontSizeMD: CGFloat = 16
    static let fontSizeLG: CGFloat = 18
    static let fontSizeXL: CGFloat = 24
    static let fontSizeXXL: CGFloat = 32

    // Corner Radius
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSM: CGFloat = 8
}

// Color(hex:) extension for hex string → SwiftUI Color
// PrimaryButtonStyle — accent bg, white text, 16px semibold
// SecondaryButtonStyle — mediumGray bg, white text, 16px medium
// CardModifier — 16px padding, darkGray bg, 12px corner radius
// View.cardStyle() — convenience for CardModifier
```

### Key Architectural Facts
- **Dark mode only**: Forced via `.preferredColorScheme(.dark)` in TheDumpApp.swift line 21
- **No asset catalog colors**: All colors defined in code via hex strings
- **System fonts only**: SF Pro via `.font(.system(size:weight:))` — no custom fonts
- **Consistent Theme usage**: ~85% of styling goes through Theme.* constants
- **No tracking/letter-spacing**: Not used anywhere in the app
- **Standard TabView**: Uses native iOS tab bar, not custom floating pill
- **Native .searchable()**: Uses SwiftUI's built-in search, not custom search bar

---

## GAP ANALYSIS

### 1. Color Token Gaps

| Current Token | Hex | Design System Equivalent | New Light Value | New Dark Value | Status |
|---|---|---|---|---|---|
| `background` | #0d0d0d | Background | #FFFFFF | #000000 | Rename + update |
| `darkGray` | #1c1c1e | Surface | #F9F9F9 | #111111 | Rename to `surface` |
| `mediumGray` | #2c2c2e | Surface 2 | #F2F2F7 | #1A1A1A | Rename to `surface2` |
| `lightGray` | #3a3a3c | Surface 3 | #E5E5EA | #222222 | Rename to `surface3` |
| `textPrimary` | #f2f2f2 | Text Primary | #1C1C1E | #FFFFFF | Update values |
| `textSecondary` | #a0a0a0 | Text Secondary | #636366 | #999999 | Update values |
| `accent` | #ff2d55 | Accent | #FF2D55 | #FF2D55 | **EXACT MATCH** |
| `accentHover` | #e6254d | Accent Subtle | rgba(255,45,85,0.08) | rgba(255,45,85,0.08) | Repurpose |
| **MISSING** | — | Border | #E5E5EA | #2A2A2A | Add new |
| **MISSING** | — | Border Light | #ECECEC | #222222 | Add new |
| **MISSING** | — | Text Tertiary | #8E8E93 | #666666 | Add new |
| **MISSING** | — | Text Quaternary | #AEAEB2 | #555555 | Add new |
| **MISSING** | — | Success | #34C759 | #34C759 | Add new (currently hardcoded as `.green`) |
| **MISSING** | — | Warning | #FF9500 | #FF9500 | Add new (currently hardcoded as `.orange`) |
| **MISSING** | — | Info | #007AFF | #007AFF | Add new |
| **MISSING** | — | Purple | #5856D6 | #5856D6 | Add new |
| **MISSING** | — | Category tint colors (7) | 10% opacity | 12% opacity | Add new system |

**Summary: 8 current tokens → ~20+ needed. 12+ tokens missing. Accent color is an exact match.**

### 2. Typography Gaps

| Design System Level | Size | Weight | Tracking | Current App Usage | Gap |
|---|---|---|---|---|---|
| Page Title | 36px | Heavy (.heavy) | -1.5px | Not used — app shows "The Dump" at 18px semibold | Missing entirely |
| Screen Title | 34px | Heavy | -1.5px | Uses native .navigationTitle (correct for Browse) | OK for Browse, missing for Dump |
| Section Title | 28px | Bold | -1px | Not used at this size | Missing |
| Note Title | 24px | Bold | -0.8px | fontSizeXL=24 exists but no tracking applied | Add tracking |
| Category Name | 16px | Medium | — | fontSizeMD=16, weight .medium — **matches** | OK |
| Card Title | 15px | Semibold | — | Not used — jumps from 14 to 16 | Missing size |
| Body | 15px | Regular | — | Not used — jumps from 14 to 16 | Missing size |
| Card Preview | 13px | Regular | — | Not used | Missing size |
| Section Label | 10px | Semibold | +2px, UPPERCASE | Used at 12px, no uppercase, no tracking | Wrong size/style |
| Meta/Caption | 11px | Regular | — | Not used | Missing size |
| Monospace | SF Mono 12px | Regular | — | Used in VoiceMemoView for timer (64px mono) | Different context |

**Summary: No tracking/letter-spacing used anywhere. Font sizes 11, 13, 15 are missing. Bold headline style is completely absent.**

### 3. Spacing Gaps

| Design System | Value | Current | Status |
|---|---|---|---|
| xs | 4 | spacingXS = 4 | Match |
| sm | 8 | spacingSM = 8 | Match |
| sm+ | 12 | **MISSING** | Add new |
| md | 16 | spacingMD = 16 | Match |
| lg | 24 | spacingLG = 24 | Match |
| xl | 32 | spacingXL = 32 | Match |
| xxl | 48 | **MISSING** | Add new |
| xxxl | 64 | **MISSING** | Add new |
| screenH (horizontal padding) | 24 | Uses spacingMD (16) in most places | Wrong value — should be 24 |

**Summary: Missing 12, 48, 64. Screen horizontal padding is wrong (16 vs 24).**

### 4. Corner Radius Gaps

| Design System | Value | Use | Current | Status |
|---|---|---|---|---|
| 4px | Tags | **MISSING** | Add new |
| 8px | Buttons | cornerRadiusSM = 8 | Match |
| 10px | Category icons | **MISSING** | Add new |
| 12px | Cards | cornerRadius = 12 | Match |
| 16px | Capture cards | **MISSING** | Add new |
| 20px | Pills | **MISSING** | Add new |
| 50% | Circles | Used inline (.clipShape(Circle())) | OK (no token needed) |

**Summary: 2 current → 6 needed. Missing 4, 10, 16, 20.**

### 5. Component Gaps

| Design System Component | Current App Equivalent | Differences |
|---|---|---|
| **Capture Cards** (2x2, emoji icons, tinted bg circles, sub-labels, 16px radius) | `CaptureButton` in ContentView.swift:263 | Uses SF Symbols not emoji, accent color not tints, no sub-labels, 12px radius |
| **Recent Feed** (status dots with pulse animation, category badges, processing state) | `SessionHistorySection` in ContentView.swift:287 | Shows upload status only, no status dots, no pulse, no category badges |
| **Note Cards** (surface bg, border-light, 15px/600 title, 13px preview clamped 2 lines, date+tag footer) | Basic list rows in NotesListView | No card styling, no media type icons, no preview clamping |
| **Filter Pills** (horizontal scroll, active=black/inactive=surface-2, 20px radius) | **Not implemented** | Completely missing |
| **Search Bar** (surface-2 bg, border, 12px radius, custom styled) | Native `.searchable()` in BrowseView | Native is functional but doesn't match visual spec |
| **Floating Tab Bar** (pill-style, centered, 28px container radius, gradient fade) | Standard `TabView` in MainTabView.swift | Completely different pattern |
| **Category Icons** (38x38, emoji in tinted bg circle, 10px radius, hash-based color) | **Not implemented** | Completely missing |
| **Buttons** (Primary=black bg, Secondary=surface-2, Ghost=transparent+border, Accent=red) | PrimaryButtonStyle uses accent(red) bg, SecondaryButtonStyle uses mediumGray | Primary button color is WRONG — spec says black, current uses accent |

---

## HARDCODED VALUES THAT BYPASS THEME.SWIFT

These must be fixed before or during the design system implementation:

### ContentView.swift
- Line 31: `size: 18` (header title — should be page title token)
- Line 40: `padding(8)` (gear button — should use spacingSM)
- Line 272: `size: 28` (capture icon)
- Line 300: `size: 24` (empty tray icon)
- Line 350: `spacing: 2` (session row)
- Line 405: `.green` (system color, should be Theme.success)
- Line 462: `.orange` (system color, should be Theme.warning)

### NoteDetailView.swift
- Line 248: `spacing: 4`, `size: 10` (metadata pill internals)
- Lines 255-256: `padding(.horizontal, 8)`, `padding(.vertical, 4)` (pill padding)
- Line 258: `.cornerRadius(12)` (should use token)
- Lines 385-386: `padding(.horizontal, 10)`, `padding(.vertical, 6)` (tag chip)
- Line 388: `.cornerRadius(14)` (not any token value)

### BrowseView.swift
- Line 237: `padding(.vertical, 8)`
- Line 285: `padding(.vertical, 4)`

### VoiceMemoView.swift
- Line 27: `size: 64` (timer display)
- Line 269: `lineWidth: 4`, `width: 80, height: 80` (record button)
- Line 373: `size: 56` (play button)

### TheDumpApp.swift
- Line 21: `.preferredColorScheme(.dark)` (forces dark mode)
- Line 43: `tint: .white` (hardcoded in RootView loading spinner)

---

## CUSTOM COMPONENTS INVENTORY (Need Styling Updates)

| Component | File:Line | Current Styling | What Needs to Change |
|---|---|---|---|
| `PrimaryButtonStyle` | Theme.swift:61 | Accent bg, white text | Change to black bg (text-primary) |
| `SecondaryButtonStyle` | Theme.swift:75 | mediumGray bg, white text | Change to surface-2 bg, add border |
| `CardModifier` | Theme.swift:87 | darkGray bg, 12px radius | Change to surface bg, add border-light |
| `CaptureButton` | ContentView.swift:263 | SF Symbol icon in accent color | Change to emoji + tinted bg circle + sub-label |
| `SessionItemRow` | ContentView.swift:324 | Upload status row | Redesign as Recent Feed item with status dot |
| `StatusBanner` | ContentView.swift:207 | darkGray bg | Update to surface bg |
| `BlockedBanner` | ContentView.swift:434 | accent.opacity(0.1) bg | Update to use semantic warning colors |
| `UsageWarningBanner` | ContentView.swift:455 | `.orange` system color | Use Theme.warning |
| `MetadataPill` | NoteDetailView.swift:243 | darkGray bg, hardcoded sizes | Update to design system pill spec |
| `TagChip` | NoteDetailView.swift:378 | mediumGray bg, 14px radius | Update to 4px radius per tag spec |
| `RecordButton` | VoiceMemoView.swift:260 | accent ring + fill, hardcoded sizes | Update sizes to tokens |
| `CircleButton` | VoiceMemoView.swift:285 | mediumGray bg | Update to surface bg |
| `WaveformView` | VoiceMemoView.swift:305 | accent color bars | Keep or update |
| `PlaybackControls` | VoiceMemoView.swift:336 | accent tint slider | Keep (accent is appropriate here) |
| `FlowLayout` | NoteDetailView.swift:392 | Spacing hardcoded at 8 | Use token |
| `BrowseFolderRowView` | BrowseView.swift:269 | Simple HStack | Add category emoji icon per design system |
| `SearchResultRowView` | BrowseView.swift:213 | Basic text stack | Update typography to card title/preview spec |

---

## ARCHITECTURAL ASSESSMENT

### What's Working Well (Keep)
1. **`enum Theme` with static properties** — Simple, zero-overhead, readable. Every view references it consistently. This pattern is correct for an app this size.
2. **`ButtonStyle` protocol usage** — `PrimaryButtonStyle` and `SecondaryButtonStyle` are the proper SwiftUI pattern. Just need value updates.
3. **`ViewModifier` for cards** — `CardModifier` is correct. Just needs value updates.
4. **Color(hex:) extension** — Clean, reusable. Can keep for any colors not in asset catalog.
5. **View composition** — Subviews like `CaptureButton`, `SessionItemRow` are well-extracted.

### What Must Change (Blockers)
1. **Remove `.preferredColorScheme(.dark)`** from TheDumpApp.swift — this is the single biggest blocker
2. **Move colors to asset catalog** with light/dark variants — this is the only structural change needed for automatic color scheme switching
3. **Rename colors semantically** — `darkGray` → `surface`, `mediumGray` → `surface2`, etc. Presentational names break in light mode.
4. **Add missing color tokens** — borders, text tertiary/quaternary, semantic colors, category tints

### What Should Change (Quality)
5. Add typography tokens that bundle size + weight + tracking as Text extensions
6. Add missing spacing values (12, 48, 64)
7. Add missing corner radius tokens (4, 10, 16, 20)
8. Fix all hardcoded values listed above to use tokens
9. Fix PrimaryButtonStyle to use black bg instead of accent bg

### What's Fine As-Is (Don't Over-Engineer)
- Static properties on an enum (don't switch to EnvironmentKey — overkill for 18 views)
- Inline `.font(.system(...))` calls (standard SwiftUI — Text extensions for typography are a nice addition but not required)
- No custom font imports needed (SF Pro is correct for iOS per design system)
- Standard TabView (evaluate if floating pill tab bar is truly worth the complexity)

---

## RECOMMENDED APPROACH FOR LIGHT/DARK MODE

### Best Option: Asset Catalog Colors + @AppStorage Toggle

1. **Define all colors in xcassets** with Light and Dark variants — SwiftUI automatically uses the right one based on color scheme
2. **Add a user preference** with `@AppStorage("appearance")` — options: System (default), Light, Dark
3. **Apply at app root** with `.preferredColorScheme(resolvedScheme)` where `resolvedScheme` is nil for System, .light for Light, .dark for Dark
4. **Theme.swift references asset catalog colors** via `Color("surface")` instead of `Color(hex: "...")`

### Why Not Other Approaches
- **Custom EnvironmentKey**: Over-engineered for 18 views. Asset catalog gives you automatic switching with no custom infrastructure.
- **Code-only with colorScheme check**: Requires wrapping every color in a computed property checking `@Environment(\.colorScheme)`. More code than asset catalog approach.
- **Keep dark only**: Conflicts with design system requirement for light mode default.

### iOS Default Behavior
Follow system setting by default (not force light mode). The design system says "light mode default" but on iOS, respecting the user's system-wide appearance setting is the platform convention. Let users override in Settings if they want.

---

## RECOMMENDED TYPOGRAPHY APPROACH

Use Text extensions that bundle size + weight + tracking:

```swift
extension Text {
    func pageTitle() -> some View {
        self.font(.system(size: 36, weight: .heavy)).tracking(-1.5)
    }
    func screenTitle() -> some View {
        self.font(.system(size: 34, weight: .heavy)).tracking(-1.5)
    }
    func sectionTitle() -> some View {
        self.font(.system(size: 28, weight: .bold)).tracking(-1)
    }
    // etc.
}
```

Call site: `Text("DUMP IT.").pageTitle()` — simple, readable, one-liner.

**Note on `.tracking()` vs `.kerning()`**: Use `.tracking()` — it maps to CSS letter-spacing. `.kerning()` adjusts individual character pairs which is not what the design system specifies.

**Accessibility concern**: Negative tracking (-1.5) on headlines can be problematic at Dynamic Type accessibility sizes. Consider reducing or removing tracking when Dynamic Type is above .xxxLarge.

---

## RISK ANALYSIS (DEVIL'S ADVOCATE)

### High Risk
- **Floating tab bar**: Replacing standard `TabView` with a custom floating pill is the highest-risk change. It affects navigation, safe areas, gesture handling, and VoiceOver accessibility. Consider just styling the standard tab bar instead.

### Medium Risk
- **Light/dark flip**: Every view uses `Theme.background.ignoresSafeArea()` — this will work fine with asset catalog colors. But the handful of hardcoded `.green`, `.orange`, and `.white` values will look wrong in one mode.
- **PrimaryButtonStyle color change**: Going from red (accent) to black changes the visual weight of every primary button in the app. Users may find the app feels less vibrant.

### Low Risk
- **Token expansion**: Going from 8 to 20+ tokens is manageable. Risk is just picking the wrong token — mitigated by semantic naming.
- **Typography tracking**: `.tracking(-1.5)` is purely additive — won't break existing layouts. Just visual refinement.
- **Spacing changes**: Screen horizontal padding changing from 16 to 24 will make content narrower. Mostly cosmetic.

### The "Do Nothing Plus" Option
If time is limited, just doing Phase 1 below (Theme.swift + asset catalog) gets ~80% of the visual improvement with ~20% of the effort. Component-level changes can be done incrementally afterward.

---

## PHASED IMPLEMENTATION PLAN

### Phase 1: Foundation (Theme.swift + Asset Catalog) — Do First
**Goal: All design system tokens exist and light/dark mode works**

1. Create asset catalog color sets for every design system color with light + dark variants:
   - background, surface, surface2, surface3
   - border, borderLight
   - textPrimary, textSecondary, textTertiary, textQuaternary
   - accent (same both modes), accentSubtle
   - success, warning, info, purple

2. Update Theme.swift:
   - Change all color definitions to reference asset catalog: `static let background = Color("background")`
   - Rename semantically: darkGray → surface, mediumGray → surface2, lightGray → surface3
   - Add missing tokens: border, borderLight, textTertiary, textQuaternary, success, warning, info
   - Add missing spacing: smPlus=12, xxl=48, xxxl=64, screenH=24
   - Add missing corner radii: tags=4, catIcon=10, capture=16, pill=20
   - Add typography Text extensions with tracking

3. Update TheDumpApp.swift:
   - Remove `.preferredColorScheme(.dark)`
   - Add `@AppStorage("appearance")` toggle support
   - Default to following system setting

4. Fix all hardcoded values identified in the audit (replace with Theme.* tokens)

5. Update existing ViewModifiers:
   - PrimaryButtonStyle: accent bg → textPrimary bg (black in light, white in dark)
   - SecondaryButtonStyle: mediumGray → surface2, add border
   - CardModifier: darkGray → surface, add borderLight

6. Replace inline `.green` and `.orange` with Theme.success and Theme.warning

**Expected outcome: App renders correctly in both light and dark mode with new color palette.**

### Phase 2: Component Updates (View-by-View) — Do Second
**Goal: Each screen matches the design system component specs**

1. **ContentView (Dump screen)**:
   - Update header to "DUMP IT." with pageTitle typography
   - Update CaptureButton to use emoji + tinted bg circles + sub-labels + 16px radius
   - Update SessionHistorySection → Recent Feed with status dots, pulse animation, category badges
   - Apply 24px horizontal screen padding

2. **BrowseView**:
   - Add category emoji icons to BrowseFolderRowView
   - Update section labels to section label typography (10px, semibold, uppercase, +2 tracking)
   - Apply 24px horizontal screen padding

3. **NotesListView / NoteDetailView**:
   - Apply note card spec (surface bg, border-light, 15px/600 title, 13px/400 preview, 2-line clamp)
   - Update MetadataPill and TagChip to design system specs
   - Add media type emoji indicators (📝🎙📷📄) to cards

4. **VoiceMemoView**:
   - Update sizes to use tokens
   - Update CircleButton bg to surface

5. **AuthView / OnboardingView / SettingsView**:
   - Apply new color tokens
   - Update typography

### Phase 3: New Components — Do Third
**Goal: Add components that don't exist yet**

1. **Filter Pills component** — horizontal scroll, active/inactive states, 20px radius
2. **Category Icon system** — hash-based tint color assignment, 38x38 container, emoji rendering, letter fallback
3. **Appearance toggle in Settings** — System/Light/Dark picker using @AppStorage
4. **Evaluate floating tab bar** — weigh visual benefit vs. complexity/accessibility cost. Recommendation: style the standard TabView rather than replacing it.

### Phase 4: Polish
1. Add accent color usage audit — ensure accent is only used per rules (1 CTA per screen, status dots, category badge, destructive confirm)
2. Dynamic Type testing — verify tracking values work at accessibility sizes
3. Dark mode testing — verify all screens in both modes
4. VoiceOver testing — ensure all components are accessible

---

## KEY DECISIONS TO MAKE BEFORE IMPLEMENTATION

1. **Standard TabView vs Floating Pill Tab Bar?** — Recommendation: keep standard, style it. Custom is risky.
2. **Follow system appearance vs force light?** — Recommendation: follow system, let user override in Settings.
3. **Asset catalog vs code-only for colors?** — Recommendation: asset catalog (automatic light/dark switching, less code).
4. **Typography extensions vs inline?** — Recommendation: Text extensions for the headline styles with tracking, inline for simpler styles.
5. **Incremental migration vs big bang?** — Recommendation: Phase 1 (foundation) as a single PR, then Phase 2 view-by-view.

---

## ACCENT COLOR USAGE AUDIT

The design system restricts accent (#FF2D55) to specific uses. Current violations to fix:

| Current Usage | File | Allowed? | Fix |
|---|---|---|---|
| PrimaryButtonStyle bg | Theme.swift:70 | NO — primary should be black | Change to textPrimary |
| CaptureButton icons | ContentView.swift:273 | NO — should be tinted emoji | Redesign capture cards |
| Error text coloring | Multiple files | MAYBE — could use warning instead | Evaluate |
| "Edit" / "Save" button text | NoteDetailView.swift:134,140 | YES — primary CTA | Keep |
| "Done" button text | NoteDetailView.swift:332 | YES — primary CTA | Keep |
| RecordButton ring/fill | VoiceMemoView.swift:268-278 | YES — primary CTA | Keep |
| Playback slider tint | VoiceMemoView.swift:362 | OK — interactive element | Keep |
| Tab bar tint | MainTabView.swift:16 | Evaluate — design says nav elements no | Consider textPrimary |
| BlockedBanner icon | ContentView.swift:440 | MAYBE — warning might be better | Consider warning |
| Waveform bars | VoiceMemoView.swift:314 | OK — decorative/status | Keep |

---

## FILES THAT WILL NEED CHANGES

### Definitely Modified
- `Theme.swift` — complete overhaul of tokens and modifiers
- `TheDumpApp.swift` — remove forced dark mode, add appearance setting
- `ContentView.swift` — capture cards, recent feed, header typography, hardcoded values
- `BrowseView.swift` — category icons, section labels, hardcoded padding
- `NoteDetailView.swift` — card styling, metadata pills, tag chips, hardcoded values
- `NotesListView.swift` — card styling, note previews
- `VoiceMemoView.swift` — hardcoded sizes, button colors
- `MainTabView.swift` — tab bar styling/replacement
- `Assets.xcassets/` — add all color sets with light/dark variants

### Likely Modified
- `AuthView.swift` — color updates, TextFieldStyles
- `TextNoteView.swift` — color updates
- `SettingsView.swift` — color updates, add appearance toggle
- `OnboardingCategoriesView.swift` — chip styling
- `OnboardingView.swift` — background color
- `AuthStatusFooter.swift` — color updates
- `AddSubCategoryView.swift` — color updates
- `CategoryManagementView.swift` — color updates
- `BrowseFolderDestinationView.swift` — color updates, filter pills addition

### No Changes Expected
- All Model files
- All Service files
- All ViewModel/State files (no styling in these)
- `CameraView.swift` (system camera UI)
