# Backend Setup Guide for StoreKit Integration

Everything the backend needs to do so the iOS purchase flow works end-to-end.

---

## 1. Environment Variables to Set

These are all required. The backend's `SignedDataVerifier` uses them to verify that purchase transactions are legitimate and actually came from your app.

| Variable | Value | Where to find it |
|---|---|---|
| `APPLE_APP_ID` | `6759177500` | App Store Connect > Your App > General > App Information > Apple ID |
| `APPLE_BUNDLE_ID` | `George-Labs.The-Dump-App-Two` | Your Xcode project's bundle identifier |
| `APPLE_KEY_ID` | *(your key ID)* | App Store Connect > Users and Access > Integrations > In-App Purchase > Keys |
| `APPLE_ISSUER_ID` | *(your issuer ID)* | Same page as above, shown at the top |
| `APPLE_PRIVATE_KEY` | *(contents of your .p8 file)* | Downloaded when you created the key (one-time download) |
| `APPLE_ENVIRONMENT` | `Sandbox` (for now) | Change to `Production` when you go live |

### How to get the Key ID, Issuer ID, and Private Key

1. Go to **App Store Connect > Users and Access > Integrations** (top menu)
2. Click **In-App Purchase** in the left sidebar under "Keys"
3. Click **Generate In-App Purchase Key**
4. Give it a name (e.g., "The Dump IAP Key")
5. Download the `.p8` file — **save it somewhere safe, you can only download it once**
6. The **Key ID** is shown next to the key name (e.g., `ABC123DEFG`)
7. The **Issuer ID** is shown at the top of the page (a UUID like `12345678-abcd-efgh-ijkl-123456789012`)

### Setting the private key

**For Cloud Run (production):**
```bash
# Store in Google Secret Manager
gcloud secrets create apple-private-key --data-file=AuthKey_XXXX.p8

# Mount as env var in your Cloud Run service
```

**For local development:**
```bash
export APPLE_PRIVATE_KEY=$(cat AuthKey_XXXX.p8)
```

---

## 2. Apple Root Certificates

The `SignedDataVerifier` needs Apple's root certificates to verify JWS signatures.

1. Download from https://www.apple.com/certificateauthority/:
   - `AppleRootCA-G3.cer` (required)
   - `AppleRootCA-G2.cer` (recommended)

2. Place them in a `certs/` directory at your backend project root:
   ```
   your-backend/
     certs/
       AppleRootCA-G3.cer
       AppleRootCA-G2.cer
   ```

3. Load them in your backend code:
   ```python
   root_certs = []
   for cert_file in ['certs/AppleRootCA-G3.cer', 'certs/AppleRootCA-G2.cer']:
       with open(cert_file, 'rb') as f:
           root_certs.append(f.read())
   ```

---

## 3. App Store Server Notifications URL

Tell Apple where to send webhook notifications (subscription renewals, expirations, refunds, etc.):

1. Go to **App Store Connect > Your App > General > App Information**
2. Scroll down to **App Store Server Notifications**
3. Set the **Production Server URL** to: `https://thedump.ai/apple-webhook`
4. Set the **Sandbox Server URL** to: `https://thedump.ai/apple-webhook` (same URL is fine)
5. Select **Version 2** for the notification format

---

## 4. Complete the Subscription Metadata

Your subscription currently shows "Missing Metadata". In App Store Connect, you need to fill in:

1. **Subscription Price** — set pricing in at least one territory
2. **Subscription Description** — what the user gets (shown on the App Store)
3. **App Store Localization** — display name and description in at least one language
4. **Review Screenshot** — a screenshot of your paywall/subscription UI (required for App Review)

---

## 5. Deployment Checklist

### Before sandbox testing
- [ ] Set `APPLE_BUNDLE_ID` env var to `George-Labs.The-Dump-App-Two`
- [ ] Set `APPLE_APP_ID` env var to `6759177500`
- [ ] Set `APPLE_KEY_ID` env var
- [ ] Set `APPLE_ISSUER_ID` env var
- [ ] Set `APPLE_PRIVATE_KEY` env var (from .p8 file)
- [ ] Set `APPLE_ENVIRONMENT` to `Sandbox`
- [ ] Download and place Apple root certificates in `certs/`
- [ ] Set App Store Server Notifications URL in App Store Connect

### Before production launch
- [ ] Change `APPLE_ENVIRONMENT` to `Production`
- [ ] Complete subscription metadata in App Store Connect (pricing, description, screenshot)
- [ ] Submit app with subscription for App Review
