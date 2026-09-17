# 🎨 Booru Gallery — Multi-Source Image Aggregator

A premium Flutter app aggregating Rule34.xxx, e621, Gelbooru, and Paheal with Apple-level aesthetics.

## Signing Details (Pre-configured from your files)

| Field | Value |
|-------|-------|
| **Bundle ID** | `app.starfruit8199.snowleopard5722` |
| **Team** | qa ba |
| **Team ID** | `SE4UL3VJW5` |
| **Cert CN** | `iPhone Distribution: qa ba (SE4UL3VJW5)` |
| **Profile UUID** | `e52b0627-df22-4cd5-b59f-a1224fad20ed` |
| **Profile Type** | Ad Hoc |
| **Provisioned Device** | `00008150-00150DAE3ED8401C` |
| **Cert Expiry** | September 10, 2027 |

---

## 🚀 GitHub Actions — Setting Up Secrets

### Step 1: Encode your files to base64

On macOS/Linux terminal:
```bash
# Encode your .p12
base64 -i certificate_00008150-00150DAE3ED8401C.p12 | pbcopy
# → paste this as P12_BASE64 secret

# Encode your .mobileprovision
base64 -i provision_1.mobileprovision | pbcopy
# → paste this as MOBILEPROVISION_BASE64 secret
```

On Windows (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate_00008150-00150DAE3ED8401C.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("provision_1.mobileprovision")) | Set-Clipboard
```

### Step 2: Add GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 4 secrets:

| Secret Name | Value |
|-------------|-------|
| `P12_BASE64` | Output of base64 encoding your `.p12` |
| `P12_PASSWORD` | `kravasign` |
| `MOBILEPROVISION_BASE64` | Output of base64 encoding your `.mobileprovision` |
| `KEYCHAIN_PASSWORD` | Any random string, e.g. `ci_keychain_2024` |

### Step 3: Push to trigger build

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

Or go to **Actions** tab → **Build & Sign iOS IPA** → **Run workflow** → **Run workflow**

### Step 4: Download your IPA

Actions tab → click the completed run → scroll to **Artifacts** → download `BooruGallery-IPA-*`

### Step 5: Install on your device

Since this is **Ad Hoc**, install via:
```bash
# Via ideviceinstaller (macOS)
ideviceinstaller -i BooruGallery_AdHoc_main_abc1234.ipa

# Via AltStore / Sideloadly (easier, no dev tools needed)
# Drag the IPA into Sideloadly with your device connected

# Via Apple Configurator 2 (Mac App Store, free)
# Add → App → choose the IPA
```

> ⚠️ **Ad Hoc** means it installs only on the device UDID `00008150-00150DAE3ED8401C` (the device registered in your provisioning profile). To add more devices you need to update your provisioning profile at developer.apple.com.

---

## 🛠 Local Development

### Prerequisites
- Flutter 3.19+: `flutter --version`
- Xcode 15+ (for iOS)
- CocoaPods: `sudo gem install cocoapods`

### Run
```bash
flutter pub get
cd ios && pod install && cd ..
flutter run                    # debug on simulator
flutter run --release          # release on connected device
```

### Build IPA locally (requires macOS with your cert imported)
```bash
# Import your cert into macOS keychain first:
security import certificate_00008150-00150DAE3ED8401C.p12 \
  -P kravasign -T /usr/bin/codesign

# Install provisioning profile:
cp provision_1.mobileprovision \
  ~/Library/MobileDevice/Provisioning\ Profiles/1d6050ac-28cb-4ab9-9e0b-82d23201f041.mobileprovision

# Build:
flutter build ios --release --no-codesign
cd ios
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath /tmp/BooruGallery.xcarchive \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=UDFVUP2APY \
  CODE_SIGN_IDENTITY="Apple Distribution: xiaoling yan (UDFVUP2APY)" \
  PROVISIONING_PROFILE_SPECIFIER="1d6050ac-28cb-4ab9-9e0b-82d23201f041" \
  PRODUCT_BUNDLE_IDENTIFIER=app.coral4330.carrot5939

xcodebuild -exportArchive \
  -archivePath /tmp/BooruGallery.xcarchive \
  -exportPath build/ios/ipa \
  -exportOptionsPlist ExportOptions.plist
```

---

## 📱 App Features

### Sources
| Source | Auth | Favorites | Voting | Rate Limit |
|--------|------|-----------|--------|------------|
| rule34.xxx | Username + API Key | ✗ (API limitation) | ✗ | Higher with auth |
| e621.net | Username + API Key | ✅ | ✅ | 2 req/s anon, higher auth |
| Gelbooru | User ID + API Key | ✅ (via API) | ✗ | Higher with auth |
| Paheal | None needed | ✗ | ✗ | Anonymous |

### How to get API keys
- **Rule34.xxx**: My Account → Account Options → API Access → API Key
- **e621**: Account → Manage API Access → Generate New Key  
- **Gelbooru**: My Account → API → Your API key is shown

### Search Syntax
```
# Single tag
solo

# Multiple tags (AND)
solo animated

# Score filter
solo score:>=100

# Exclusion
solo -male

# Rating
solo rating:safe

# Artist
solo artist:john_doe

# Character  
solo character:rem_(re:zero)
```

---

## 🏗 Architecture

```
lib/
├── core/
│   ├── theme/           # AppTheme, AppColors, AppTextStyles
│   └── utils/           # Logger
├── data/
│   ├── datasources/     # BooruDataSource impls (R34, e621, Gelb, Paheal)
│   └── repositories/    # SearchRepository, LocalRepository
├── domain/
│   └── entities/        # Post, PostTag, SearchQuery, BooruSource
└── presentation/
    ├── blocs/           # SearchBloc (events/state)
    ├── screens/
    │   ├── home/        # Landing, recent searches, source selector
    │   ├── search/      # Tag search, grid results, infinite scroll
    │   ├── viewer/      # Full-screen gallery, video player, details panel
    │   ├── favorites/   # Local saved posts grid
    │   ├── settings/    # Theme, columns, blacklist, auth links
    │   └── auth/        # Per-source login screen
    └── widgets/
        ├── common/      # GlassCard, SourceBadge
        ├── grid/        # PostGrid, PostTile (with shimmer, badges)
        └── search/      # SearchBarWidget, FilterSheet
```

---

## ⚠️ Troubleshooting

**"No signing certificate found"**  
→ Make sure `P12_BASE64` is the correct base64 of your .p12 (not the file path)

**"Profile not found"**  
→ Make sure `MOBILEPROVISION_BASE64` is correct. The profile UUID is `1d6050ac-28cb-4ab9-9e0b-82d23201f041`.

**"Provisioned device does not match"**  
→ Your Ad Hoc profile only covers UDID `00008150-00150DAE3ED8401C`. Install only on that device, or regenerate the profile with additional UDIDs at developer.apple.com.

**Build timeout**  
→ First build takes ~15-20min on GitHub Actions (pod install + full compile). Subsequent runs with cache ~8-12min.

**Flutter pub get fails**  
→ Some packages require network access. The `xml` package for Paheal XML parsing is included.
