# Apple App Store Submission Checklist — The Dump

## App Store Connect Setup
- [ ] App name, subtitle, description, keywords, category (Productivity or Utilities)
- [ ] Screenshots for all required device sizes (6.7", 6.5", 5.5" minimum; iPad if supported)
- [ ] App icon 1024x1024 uploaded to App Store Connect
- [ ] Age rating questionnaire completed (likely 4+ since no user-generated content is shared publicly)
- [ ] App Review contact info filled in
- [ ] Demo account credentials provided for reviewer (they need to log in and test the full flow)
- [ ] Review notes explaining: free tier allows 150 notes/mo, Pro unlocks 2,500 notes + 500K words

## Privacy & Legal
- [ ] Privacy Policy live at https://thedumpapp.com/privacy
- [ ] Terms of Use live at https://thedumpapp.com/terms
- [ ] Privacy Policy URL entered in App Store Connect
- [ ] App Privacy "nutrition labels" declared:
  - Contact Info: email address (account creation)
  - User Content: photos, audio, files, text notes
  - Identifiers: user ID
  - Usage Data: app usage / analytics (if any)
  - Diagnostics: crash logs (if any)
- [ ] Third-party SDK usage declared (Firebase Auth, StoreKit)

## In-App Purchase Setup
- [ ] Subscription product created in App Store Connect
- [ ] Product ID matches StoreKitService configuration in the app
- [ ] Subscription Group created and named
- [ ] Subscription display name and description filled in (visible on Apple's subscription sheet)
- [ ] Price and territory availability set
- [ ] App Store Server Notifications v2 endpoint configured on backend (for renewals, cancellations, billing retries, refunds)

## Technical / Code
- [x] Restore Purchases button in PaywallView
- [x] Subscription management link (itms-apps://) in Settings
- [x] Clear pricing display with tier comparison (Free vs Pro)
- [x] Terms of Use link in PaywallView
- [x] Privacy Policy link in PaywallView and SettingsView
- [x] Free tier is fully functional (150 notes, browsing/reading always works)
- [x] Blocked users can still read existing notes (only new capture is gated)
- [x] iOS client uses new response fields (notes_used, monthly_note_limit, words_used, monthly_word_limit, blocked_reason)
- [ ] Signing & provisioning profiles configured for distribution (Apple Developer account)
- [ ] Export compliance declaration (select "No" — only using HTTPS, no custom encryption)
- [ ] Full purchase flow tested in StoreKit Sandbox
- [ ] Restore Purchases tested in StoreKit Sandbox
- [ ] Test that app works on free tier without paying (Apple will reject if core features are locked)
- [ ] Test blocked state: verify user can browse/read notes but cannot create new ones

## Common Rejection Reasons to Avoid
- Don't reference "free trial" in UI unless it's configured as an introductory offer in App Store Connect
- Subscribe button must show the actual price from StoreKit (already doing this with displayPrice)
- App must not become completely unusable at the limit (already handled — read access is preserved)
- All external links (Terms, Privacy) must load successfully at review time
- If using "Sign in with Apple" is offered alongside other auth, Apple requires it — verify if this applies
