# 🚀 RailShift Manager — Play Store Publishing Guide
> Simple, step-by-step guide to get your app live on Google Play Store.

---

## 📋 TABLE OF CONTENTS
0. [Personal vs Organisation Account — Which to Choose?](#0-personal-vs-organisation-account--which-to-choose)
1. [Things You Need (Before You Start)](#1-things-you-need-before-you-start)
2. [Step 1 — Fix Your Package Name](#2-step-1--fix-your-package-name)
3. [Step 2 — Create a Release Keystore (Signing Key)](#3-step-2--create-a-release-keystore-signing-key)
4. [Step 3 — Configure Release Signing in Gradle](#4-step-3--configure-release-signing-in-gradle)
5. [Step 4 — Create a Google Play Developer Account](#5-step-4--create-a-google-play-developer-account)
6. [Step 5 — Prepare Store Listing Assets](#6-step-5--prepare-store-listing-assets)
7. [Step 6 — Host a Privacy Policy](#7-step-6--host-a-privacy-policy)
8. [Step 7 — Build the Release App Bundle (.aab)](#8-step-7--build-the-release-app-bundle-aab)
9. [Step 8 — Create App on Play Console & Upload](#9-step-8--create-app-on-play-console--upload)
10. [Step 9 — Fill in All Required Forms](#10-step-9--fill-in-all-required-forms)
11. [Step 10 — Internal Testing (Recommended)](#11-step-10--internal-testing-recommended)
12. [Step 11 — Submit for Production Review](#12-step-11--submit-for-production-review)
13. [Final Checklist](#13-final-checklist)
14. [Common Mistakes to Avoid](#14-common-mistakes-to-avoid)
15. [Costs Summary](#15-costs-summary)

---

## 0. Personal vs Organisation Account — Which to Choose?

When creating your Google Play Developer account, Google asks: **Are you registering as an Individual or as an Organisation?**

This is an important decision. Here's everything explained simply:

---

### 👤 PERSONAL (Individual) Account

**Choose this if:**
- You are developing the app on your own (freelancer / solo developer)
- You don't have a registered company or business
- The app is a personal project, portfolio app, or side project
- You want the simplest, fastest registration process

**What gets shown on Play Store:**
> Published by: **Your Full Name** (e.g., "Ranjith Kumar")

**What you need to provide:**
| Document / Info | Required? |
|---|---|
| Your full legal name | ✅ Yes |
| Your home address | ✅ Yes (kept private, not shown publicly) |
| Phone number | ✅ Yes (for verification) |
| Government-issued ID | ✅ Yes (Aadhaar / PAN / Passport) |
| Credit/Debit card for $25 fee | ✅ Yes |
| D-U-N-S Number | ❌ Not required |
| Business registration documents | ❌ Not required |

**Verification process:**
1. Enter your personal details
2. Google sends a verification code to your phone
3. Complete ID verification (upload Aadhaar / PAN card photo)
4. Pay $25 → Account activated within a few minutes to 2 days

---

### 🏢 ORGANISATION Account

**Choose this if:**
- You have a registered company (Pvt. Ltd., LLP, Partnership, etc.)
- You want the app published under a company/brand name
- You plan to have multiple developers/team members managing the account
- The app is a commercial product under a business

**What gets shown on Play Store:**
> Published by: **Your Company Name** (e.g., "RailShift Technologies Pvt. Ltd.")

**What you need to provide:**
| Document / Info | Required? | Notes |
|---|---|---|
| Company's legal name | ✅ Yes | As on registration certificate |
| Company's registered address | ✅ Yes | |
| Company phone number | ✅ Yes | |
| **D-U-N-S Number** | ✅ Yes | See below — this is the big one |
| Business registration certificate | ✅ Yes | GST certificate, MOA, or incorporation docs |
| Authorised signatory's ID proof | ✅ Yes | Aadhaar / PAN of the person signing up |
| Company PAN / GST number | ✅ Recommended | For tax purposes in India |
| Credit/Debit card for $25 fee | ✅ Yes | Can be company card or personal |

---

### 🔑 What is a D-U-N-S Number? (Organisation only)

A **D-U-N-S number** is a unique 9-digit ID given to businesses by a company called **Dun & Bradstreet (D&B)**. Google requires this to verify your organisation is a real, registered business.

**How to get a D-U-N-S number for your Indian company:**

1. Go to: **https://www.dnb.com/duns-number/get-a-duns.html**
2. Search if your company already has one
3. If not, apply for a new D-U-N-S number — it's **FREE**
4. Fill in your company details (name, address, registration number)
5. D&B will verify with government records
6. You'll receive your D-U-N-S number by email

⏰ **Time it takes:** Usually **5–30 business days** (can be faster with expedited options)

> **Note:** If your company is new and not yet in their database, the process may take longer. Start this early.

---

### ⚖️ Side-by-Side Comparison

| Feature | Personal | Organisation |
|---|---|---|
| Registration difficulty | Easy | Moderate |
| Time to register | Minutes to 2 days | Days to weeks (D-U-N-S) |
| D-U-N-S number needed | ❌ No | ✅ Yes |
| Business registration docs | ❌ No | ✅ Yes |
| Name shown on Play Store | Your personal name | Your company name |
| Tax handling | As individual | As business entity |
| Multiple team members | Limited | Full team access |
| Best for | Solo/personal apps | Commercial/company apps |

---

### 🇮🇳 Special Notes for India

- Google Play uses **Stripe** or **Google Payments** for the $25 fee — most Indian credit/debit cards work fine
- After registration, Google may ask you to complete **KYC (Know Your Customer)** verification
- For **Individual** accounts: Aadhaar-based verification is commonly accepted
- For **Organisation** accounts: GST registration certificate + company PAN is usually sufficient as supporting docs
- If you plan to earn money from the app (paid app / ads), you'll also need to set up a **Google AdSense or Payments Merchant account** with your bank details (IFSC, account number)

---

### ✅ Recommendation for RailShift Manager

> **If you're building this as a personal project or for your own railway crew team → go with Personal (Individual).**
>
> **If you have or plan to register a company specifically for this product → go with Organisation.**

For most solo developers in India just starting out, **Personal is the right choice** — it's faster, simpler, and requires no company documents.

---

## 1. Things You Need (Before You Start)

Before touching any code, make sure you have the following ready:

| What You Need | Details |
|---|---|
| **Google Account** | A Gmail account to register as a developer |
| **$25 USD** | One-time fee to create a Google Play Developer account (no refund) |
| **Your App Name** | The final name you want shown on Play Store (e.g., "RailShift Manager") |
| **App Description** | A short (80 chars) and a long (4000 chars) description of your app |
| **App Icon** | 512×512 pixels, PNG, no transparency |
| **Feature Graphic** | 1024×500 pixels image shown at top of Play Store listing |
| **Screenshots** | At least 2 phone screenshots (min 320px, max 3840px on any side) |
| **Privacy Policy URL** | A publicly accessible web link to your privacy policy (free options exist) |
| **Contact Email** | Email shown on your store listing for users to contact you |

---

## 2. Step 1 — Fix Your Package Name

> ⚠️ **THIS IS CRITICAL.** Google Play **will reject** any app with a package name starting with `com.example`. You must change it before you do anything else.

Your current package name is: `com.example.railshift_manager`

### How to change it:

**Option A — Easiest Way (using `rename` package):**

1. Open your terminal in the project folder and run:
   ```bash
   dart pub global activate rename
   ```
2. Then run (replace with your chosen name, e.g., use your name or company):
   ```bash
   dart pub global run rename setBundleId --targets android --value "com.yourname.railshiftmanager"
   ```
   Example: `com.ranjith.railshiftmanager` or `com.railshift.manager`

**Option B — Manually:**

1. Open `android/app/build.gradle.kts`
2. Find line 25 and change:
   ```kotlin
   // CHANGE THIS:
   applicationId = "com.example.railshift_manager"
   // TO SOMETHING LIKE THIS:
   applicationId = "com.yourname.railshiftmanager"
   ```
3. Open `android/app/src/main/AndroidManifest.xml` — the manifest will update automatically via the namespace in build.gradle.

> **Note:** Once you publish with a package name, you can NEVER change it. Pick something you like and that represents you/your company.

---

## 3. Step 2 — Create a Release Keystore (Signing Key)

Think of this as a "digital stamp" that proves the app belongs to you. **Keep this file safe forever!** If you lose it, you can never update your app on Play Store.

### Run this command in your terminal (anywhere):

```bash
keytool -genkey -v -keystore railshift_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias railshift_key
```

It will ask you several questions:
- **Keystore password** → Create a strong password, write it down somewhere safe
- **First and last name** → Your name (e.g., Ranjith)
- **Organization unit** → Can leave blank or type your team name
- **Organization** → Your name or company
- **City/Locality** → Your city
- **State/Province** → Your state
- **Country code** → IN (for India)

After this, a file called `railshift_release.jks` will be created. **Move it to your project root folder** (`d:\Flutter Projects\RailShift Manager\`).

> ⚠️ **NEVER commit the `.jks` file or passwords to GitHub/GitLab!** Add `*.jks` to your `.gitignore`.

---

## 4. Step 3 — Configure Release Signing in Gradle

Now you need to tell your app to use this key when building for release.

### Step 3a — Create a `key.properties` file

Create a new file called `key.properties` in your `android/` folder (`android/key.properties`) with this content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD_HERE
keyPassword=YOUR_KEY_PASSWORD_HERE
keyAlias=railshift_key
storeFile=../../railshift_release.jks
```

Replace `YOUR_KEYSTORE_PASSWORD_HERE` and `YOUR_KEY_PASSWORD_HERE` with the passwords you chose in Step 2.

> ⚠️ Add `key.properties` to your `.gitignore` so it's never uploaded to GitHub!

### Step 3b — Update `android/app/build.gradle.kts`

Open `android/app/build.gradle.kts` and update it to look like this:

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.yourname.railshiftmanager"   // <-- your new package name
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.yourname.railshiftmanager"  // <-- your new package name
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")  // <-- USE RELEASE KEY
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

---

## 5. Step 4 — Create a Google Play Developer Account

1. Go to: **https://play.google.com/console**
2. Sign in with your Google account
3. Click **"Get started"**
4. Accept the Developer Distribution Agreement
5. Pay the **$25 one-time registration fee** (credit/debit card)
6. Fill in your developer profile:
   - Developer name (shown on Play Store, e.g., "Ranjith Dev" or your company name)
   - Contact email
   - Website (optional but recommended)
7. Account will be activated within a few minutes to 48 hours.

---

## 6. Step 5 — Prepare Store Listing Assets

You need to prepare these image assets before submitting:

### Required Images:
| Asset | Size | Format | Notes |
|---|---|---|---|
| **App Icon** | 512 × 512 px | PNG | No transparency allowed |
| **Feature Graphic** | 1024 × 500 px | PNG or JPG | Shown at top of your Play listing |
| **Phone Screenshots** | Min 2, max 8 | PNG or JPG | Take from actual device or emulator |

### Tips for Screenshots:
- Take at least **4-5 screenshots** showing key screens of the app
- Show the main features: login, dashboard, shift management, notifications
- You can add text overlays using free tools like **Canva.com**

### Required Text:
| Field | Limit | Tips |
|---|---|---|
| **App name** | 30 chars | e.g., "RailShift Manager" |
| **Short description** | 80 chars | e.g., "Smart duty & shift manager for railway crew" |
| **Full description** | 4000 chars | Explain features, benefits, who it's for |

---

## 7. Step 6 — Host a Privacy Policy

Your app uses the internet and sends notifications, so Google **requires** a privacy policy.

### Free & Easy Way — Use GitHub Pages or Google Sites:

**Option A — GitHub Gist (Simplest):**
1. Go to **https://gist.github.com**
2. Create a new public gist with your privacy policy text
3. The raw URL becomes your privacy policy link

**Option B — Google Sites (No coding needed):**
1. Go to **https://sites.google.com**
2. Create a free site
3. Add a page titled "Privacy Policy"
4. Paste your privacy policy text
5. Publish it — that URL is your privacy policy link

### Sample Privacy Policy Content for RailShift Manager:
```
Privacy Policy for RailShift Manager

Last updated: [Date]

RailShift Manager ("the App") is developed by [Your Name].

Data We Collect:
- Login credentials (used only for authentication with our server)
- Duty schedule data (stored locally on your device)
- Notification preferences

How We Use Data:
- To display your railway crew duty schedules
- To send local notifications for upcoming duties
- We do NOT sell your data to third parties

Data Storage:
- All data is stored locally on your device using secure storage
- Server communication is encrypted via HTTPS

Contact: [your-email@gmail.com]
```

---

## 8. Step 7 — Build the Release App Bundle (.aab)

Once signing is configured and your package name is fixed, build the release version:

### Step 7a — Update pubspec.yaml version (optional but good practice):
```yaml
version: 1.0.0+1
```
- `1.0.0` is the version name shown to users
- `+1` is the version code (must be higher for every upload)

### Step 7b — Run the build command:
```bash
flutter build appbundle --release
```

This will create your release file at:
```
build/app/outputs/bundle/release/app-release.aab
```

This `.aab` file is what you upload to Play Store.

> ℹ️ A `.aab` file is smaller and more efficient than an APK. Google requires it for new apps.

---

## 9. Step 8 — Create App on Play Console & Upload

1. Go to **https://play.google.com/console**
2. Click **"Create app"**
3. Fill in:
   - App name: `RailShift Manager`
   - Default language: `English`
   - App or Game: `App`
   - Free or Paid: `Free` (if it's free)
4. Accept the declarations and click **"Create app"**
5. In the left menu, go to **"Testing" → "Internal testing"**
6. Click **"Create new release"**
7. Click **"Upload"** and select your `.aab` file from Step 7
8. Add release notes (e.g., "Initial release of RailShift Manager")
9. Click **"Save"** then **"Review release"**

---

## 10. Step 9 — Fill in All Required Forms

Play Console will show you a list of tasks to complete. Here's what each one means:

### a) Store Listing
- Upload your icon, feature graphic, and screenshots
- Fill in your app name, short description, and full description
- Set App Category: **"Productivity"** or **"Business"**
- Add your contact email and privacy policy URL

### b) App Content (Very Important!)
Google asks about your app's content. Answer honestly:

| Question | Your Answer |
|---|---|
| Target audience | Adults (18+) |
| Contains ads? | No |
| Contains in-app purchases? | No (if none) |
| Sensitive permissions? | Yes — explain `POST_NOTIFICATIONS` and `INTERNET` |

### c) Data Safety Form
You must declare what data your app collects:

| Data Type | Collected? | Notes |
|---|---|---|
| Email address | Yes | For login/authentication |
| App activity | No | — |
| Device info | No | — |
| Location | No | — |
| Financial info | No | — |

Fill this accurately. **Lying here can get your app banned.**

### d) Content Rating (IARC)
- Start the questionnaire
- Answer all questions (your app will likely get rated **"Everyone"**)
- Submit to get your official rating

---

## 11. Step 10 — Internal Testing (Recommended)

Before going live to everyone, test with internal testers first. This is **free** and **fast** (goes live within minutes).

1. In Play Console → **"Testing" → "Internal testing"**
2. Create a tester list with your own email + any friends/colleagues
3. Share the internal testing link with them
4. They can install and test from Play Store
5. Gather feedback and fix any bugs
6. Once happy → promote to Production

---

## 12. Step 11 — Submit for Production Review

When everything above is complete:

1. Go to **"Production"** in the left menu
2. Click **"Create new release"**
3. Upload the same (or a newer) `.aab` file
4. Fill in release notes
5. Click **"Start rollout to Production"**
6. Google will review your app — this takes **1 to 7 business days**

### If your app gets rejected:
- Google will email you explaining why
- Fix the issue they mention
- Rebuild the app (increment version code in pubspec.yaml: `1.0.0+1` → `1.0.0+2`)
- Re-upload and resubmit

---

## 13. Final Checklist

Go through this checklist before submitting to production:

### Code Changes:
- [ ] Package name changed from `com.example.railshift_manager` to something unique
- [ ] Release keystore (`.jks` file) created and stored safely
- [ ] `key.properties` file created in `android/` folder
- [ ] `build.gradle.kts` updated to use release signing config (not debug)
- [ ] `android:usesCleartextTraffic="true"` removed from AndroidManifest (only if your backend uses HTTPS)
- [ ] `flutter build appbundle --release` runs without errors
- [ ] `.jks` and `key.properties` added to `.gitignore`

### Play Console:
- [ ] Developer account created and $25 paid
- [ ] App created in Play Console
- [ ] `.aab` file uploaded successfully
- [ ] App icon (512×512) uploaded
- [ ] Feature graphic (1024×500) uploaded
- [ ] At least 2 phone screenshots uploaded
- [ ] App name, short & long description filled in
- [ ] Privacy policy URL added
- [ ] Data safety form completed
- [ ] Content rating questionnaire completed
- [ ] App category set (Productivity / Business)
- [ ] Contact email added

---

## 14. Common Mistakes to Avoid

| ❌ Mistake | ✅ What to Do Instead |
|---|---|
| Keeping `com.example` package name | Change it before first upload |
| Using debug signing key for release | Set up a proper release keystore |
| Losing your `.jks` keystore file | Back it up to Google Drive / USB drive |
| Not filling Data Safety form | Fill it truthfully — Google checks this |
| Uploading APK instead of AAB | Always use `flutter build appbundle` |
| Forgetting to increment `versionCode` | Each new upload needs a higher number |
| No privacy policy | Host one, even a simple page works |
| `cleartext` traffic left enabled | Use HTTPS for your backend API |
| App crashes on first launch | Test on a real device before submitting |

---

## 15. Costs Summary

| Item | Cost | Notes |
|---|---|---|
| Google Play Developer Account | **$25 USD** (one-time) | Required. Non-refundable. |
| App submission | **Free** | Included in developer account |
| Hosting privacy policy | **Free** | Use GitHub Gist, Google Sites, etc. |
| Play Store commission | **Free** (if app is free) | Google takes % only on paid apps / purchases |
| Screenshots / graphics | **Free** | Use Canva.com for free templates |
| Backend server (your API) | Varies | Depends on your hosting provider |

**Minimum cost to publish: $25 USD** (just the developer account fee)

---

## 📞 Useful Links

| Resource | URL |
|---|---|
| Google Play Console | https://play.google.com/console |
| Flutter Build Docs | https://docs.flutter.dev/deployment/android |
| Play Store Policies | https://support.google.com/googleplay/android-developer/answer/9857753 |
| Data Safety Guidance | https://support.google.com/googleplay/android-developer/answer/10787469 |
| Canva (for screenshots) | https://www.canva.com |
| Privacy Policy Generator | https://www.privacypolicygenerator.info |

---

> 💡 **Tip:** Start with Internal Testing first. It lets you test the real Play Store install experience without going public. Only move to Production once you're 100% happy with the app.

> ⚠️ **IMPORTANT:** Never lose your `.jks` keystore file. If you lose it, you will never be able to update your app. Google cannot recover it for you. Back it up in multiple places!
