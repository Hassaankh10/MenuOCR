# MenuOCR onboarding design

Active project: `/Users/muhammadhassaankhan/Developer/MenuOCR`.

Google Stitch project: https://stitch.withgoogle.com/projects/14390015597896701236

Brief: native macOS onboarding for a local screenshot-to-text menu-bar utility; warm editorial Arc-inspired personality, soft lavender/peach backdrop, original branding, four steps (welcome, local setup, shortcut, first capture), and a bottom-center copy confirmation. No account requirement. Back and setup-later remain available. Respect Reduce Motion and explain permissions before requesting them.

Stitch-generated design-system direction: Lumina Editorial macOS, indigo #6366F1, rose #F43F5E, mint #10B981, ink #0F172A, editorial serif headlines, readable sans-serif body copy, monospaced labels. The native implementation uses system fonts rather than remote fonts, retains the existing generated MenuOCR icon, and adapts controls to AppKit/SwiftUI.

## Adaptation notes

The first Stitch pass invented several unsupported product details (embedded Tesseract, Neural Engine acceleration, notarization, benchmark numbers and extra shortcut actions). A refinement prompt was submitted to remove those claims. The native implementation always uses real OS/dependency status and the configured shortcut, does not inherit unsupported features, and avoids displaying captured text in feedback. The existing generated app icon was retained.

## Verified interactions

The app was launched and all four onboarding screens were inspected through native UI automation. Continue, Back, shortcut preview and the unavailable first-capture state were exercised. The engine was detected as installed; Screen Recording was correctly reported as pending. Native raster previews were rendered for each step and checked for layout. The bottom-center feedback test checks alignment, focus preservation, unchanged clipboard during preview, automatic dismissal and message replacement. Real English OCR tests continue to pass. Screen Recording grants and actual capture/paste remain a user-authorized manual acceptance check.
