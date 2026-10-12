# MenuOCR

Native SwiftUI/AppKit menu-bar app for Apple Silicon, macOS 13+. Press **Command–Shift–O**, drag a region, and paste the recognized text anywhere. No terminal needs to remain open. Processing is entirely local using your Homebrew Tesseract installation.

## Install and run

Install Apple's Command Line Tools (or Xcode) and Homebrew from https://brew.sh if needed:

```sh
xcode-select --install
brew install tesseract
# Optional: all additional language models (slower automatic detection)
brew install tesseract-lang
```

From this project folder:

```sh
./build.sh
mkdir -p ~/Applications
cp -R dist/MenuOCR.app ~/Applications/
open ~/Applications/MenuOCR.app
```

A compiled arm64 app is also included in `dist`. It requires Tesseract at `/opt/homebrew/bin/tesseract` (or `/usr/local/bin/tesseract`). This is a locally ad-hoc-signed app, not a notarized distribution. Build locally if macOS blocks a downloaded copy, or use the normal Privacy & Security “Open Anyway” flow for a copy you trust. For distribution, sign with a Developer ID (`SIGN_IDENTITY="Developer ID Application: …" ./build.sh`) and notarize separately.

The menu-bar icon looks like a text viewfinder. There is no Dock icon. To start at login, add the installed app under System Settings → General → Login Items → Open at Login. Quit the old app before replacing it with a new build.

## Permissions

The first capture requests **Screen Recording** access. Enable **MenuOCR** in System Settings → Privacy & Security → Screen Recording (called Screen & System Audio Recording on some releases), then quit and reopen it. The menu includes a link to this pane. Keep the app in a stable installed location before granting permission. Rebuilding an ad-hoc-signed app can require granting permission again.

**Accessibility and Input Monitoring are not required.** The app registers a Carbon global hotkey; it does not inspect keystrokes or synthesize input. Clipboard writing needs no separate permission. Launch the `.app`, rather than the bare executable from Terminal, so permissions are associated with the app.

## Usage

- Capture Text or Command–Shift–O opens the system region screenshot picker. Escape cancels it.
- Settings lets you choose a letter key and Command/Shift/Option/Control modifiers. Settings persist. A conflicting registration preserves the previous shortcut; system-reserved shortcuts may still take precedence.
- The menu shows the model currently being checked, the final model code and confidence score, or an error. Hover over the icon for full status text.
- Recognized text replaces the clipboard only after successful OCR. Cancel, empty text and errors preserve it.
- Cancel stops the current capture/OCR operation. Repeated capture requests are ignored while busy.
- Copy Last Screenshot explicitly replaces the clipboard with the most recent captured PNG, even if OCR failed. The image is kept only in memory until quit or the next capture.

## Automatic language selection and limits

Tesseract has no general automatic text-language switch. MenuOCR enumerates `tesseract --list-langs`, excludes the orientation-only `osd` model, runs each installed model separately, and chooses the nonempty result with the highest character-weighted word confidence. This is a heuristic model choice, **not a calibrated language probability**. The displayed score is OCR confidence. Identical scores use the first model in sorted order.

All installed models participate, including script models if present. An incomplete comparison reports an error rather than silently ignoring broken models. Installing all Homebrew languages can require several minutes per screenshot; each model has a 45-second timeout. Install only the models you need for faster results. With only English installed, English is the only possible selection. `tesseract --list-langs` shows available models.

Short text, numbers, similar languages, script variants, mixed-language regions, rotated text and unusual layouts can produce incorrect choices. Select a clean, upright region containing several words. This version chooses one model per screenshot; it does not segment mixed-language paragraphs or perform rotation correction. Text preserves detected line breaks but normalizes spacing between words, including scripts that conventionally omit spaces. Confidence across independently trained models is not perfectly comparable.

Temporary screenshots and process output are stored in private temporary directories and deleted when the operation ends. An abrupt process kill can leave temporary files for system cleanup. No network requests, OCR history database, telemetry, or third-party Swift packages are used. The normal system clipboard (including any enabled Universal Clipboard/clipboard managers) handles copied content.

## Source and tests

`Package.swift` opens in Xcode as a Swift package. `Sources/MenuOCR/App.swift` contains menu UI, shortcut registration and capture orchestration; `OCR.swift` contains subprocess handling, model comparison and TSV parsing. `build.sh` wraps the executable in a signed agent application bundle. Use the bundle for interactive permission testing.

```sh
./check.sh # Works with Command Line Tools alone; requires Tesseract
swift test # XCTest suite requires full Xcode selected with xcode-select
./build.sh
codesign --verify --strict dist/MenuOCR.app
```

Tests cover TSV reconstruction/confidence, command failures/timeouts and real English Tesseract recognition of a generated image (skipped if Tesseract is absent).

Manual acceptance: launch installed bundle; grant Screen Recording and relaunch; capture English and another installed language; paste into TextEdit; test Escape, menu Cancel, busy shortcut, a conflicting shortcut, saved shortcut after relaunch, and Copy Last Screenshot. Also test denied permission and missing/broken models. Interactive OS permission dialogs and global hotkeys require testing in your logged-in desktop session.

References: [Tesseract CLI and TSV](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html), [language models](https://tesseract-ocr.github.io/tessdoc/Data-Files.html), [Apple screen-capture permission](https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess()).

## Validation on the development Mac

ARM64 release compilation passed with Swift 6.1.2 in Swift 5 language mode. The standalone check passed: TSV line reconstruction, confidence weighting, empty output, process error, timeout, and generated-image OCR through automatic model selection. Only `eng` and `osd` are installed here, so multilingual selection accuracy was not tested. XCTest is unavailable in the installed Command Line Tools; the equivalent standalone check was used. Bundle plist and ad-hoc signature validation passed. Interactive app launch, global hotkeys, screenshot picker, permissions and clipboard remain manual acceptance checks; launch attempts from the restricted execution environment did not succeed.

## Version 1.1: icon and interaction feedback

The application now includes a generated blue capture-and-checkmark icon (`Assets/AppIcon.png` and the bundled `AppIcon.icns`). The menu-bar symbol remains a monochrome system symbol so it adapts to the menu bar appearance; it changes while capture/OCR is busy.

Successful OCR displays **“Text copied to clipboard”**, the character count, and **“Ready to paste with ⌘V”** only after the clipboard write succeeds. This small bottom-center panel lasts four seconds, does not activate MenuOCR or take keyboard focus, and allows clicks to pass through. It appears on the display where capture was initiated. It hides before the next capture. It shows no extracted text, keeping screenshot contents out of the popup.

Settings includes **Show confirmation after copying** (enabled by default) and **Preview Confirmation** (does not change the clipboard). VoiceOver receives an announcement and gets ten seconds of display time. Native semantic colors support light/dark appearance; Reduce Transparency uses an opaque background. There are no movement animations. Success is silent. Errors use a distinct symbol and message, remain visible for ten seconds, and retain details under **Show Last Result…**. Cancellation does not show a success popup. Optional screenshot copying also confirms success.

These choices follow the principles in [Apple’s Feedback guidance](https://developer.apple.com/design/human-interface-guidelines/feedback) and [Alerts guidance](https://developer.apple.com/design/human-interface-guidelines/alerts): confirm outcomes with proportionate interruption, retain useful status, and use text as well as color. This custom transient panel is not a Notification Center notification; it requires no notification permission and is not managed by Focus. Disable copy confirmations in Settings if desired.

To replace an installed version: quit MenuOCR, replace its app bundle with `dist/MenuOCR.app`, then reopen it. Rebuilt ad-hoc signatures may require Screen Recording permission again. Run `./make-icon.sh` only to regenerate icon sizes from the master PNG; it uses macOS `sips`/`iconutil`, with a Python 3 standard-library ICNS packaging fallback. Normal builds use the included icon and do not require Python.

### Version 1.1 verification

ARM64 release build and OCR checks passed again. `./check-ui.sh` passed in this desktop session: visible popup, nonactivating window, foreground app preserved, clipboard unchanged during preview, four-second automatic dismissal, single-panel replacement, explicit dismissal, and macOS ICNS decoding. The rendered confirmation was visually inspected; a sample is saved in `Assets/Confirmation-preview.png`. This check briefly displays sample feedback without modifying the clipboard.

End-to-end capture with Screen Recording authorization, alternate displays/Spaces, VoiceOver speech, and dark/high-contrast system settings still need manual testing. These results do not constitute a full HIG/accessibility compliance audit.


## Version 1.2: onboarding and project location

The active development project is `/Users/muhammadhassaankhan/Developer/MenuOCR`. Earlier archives remain release snapshots. Build and continue development here.

The first launch opens a four-step native welcome experience: a product introduction, local Tesseract and Screen Recording checks, your currently configured shortcut plus customization/feedback preview, and first capture. Permissions are requested only after you press Enable Screen Recording. “Set up later” closes onboarding without marking it complete; “Finish without capturing” completes it. Reopen it anytime from **Welcome to MenuOCR…** in the menu bar. The first-capture button is disabled until required checks pass. Closing onboarding does not quit the menu-bar app.

The copy popup now appears at the bottom center of the capture display’s usable area, 28 points above the Dock/work-area boundary. It remains nonactivating and click-through. Automated UI checks verify its horizontal center and bottom placement, as well as dismissal, replacement, clipboard preservation and keyboard focus.

Design direction was generated in [Google Stitch](https://stitch.withgoogle.com/projects/14390015597896701236). See `Design/` for provenance, native rendered previews and any exported reference assets. It adapts a warm editorial onboarding direction to native SwiftUI; it is not a clone of Arc or a web view. The welcome canvas deliberately uses a consistent light lavender/peach palette; system settings and feedback retain their adaptive appearance. Reduced Motion disables step animations.
