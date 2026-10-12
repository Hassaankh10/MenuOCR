# MenuOCR

A macOS menu-bar app that copies text from screenshots using local Tesseract OCR.

Requires an Apple Silicon Mac running macOS 13 or later.

## Homebrew

```sh
brew tap Hassaankh10/menuocr
brew install --cask menuocr
```

## Build

Install [Homebrew](https://brew.sh), then run:

```sh
xcode-select --install
brew install tesseract

git clone https://github.com/Hassaankh10/MenuOCR.git
cd MenuOCR
./build.sh
```

The app is built at `dist/MenuOCR.app`. To install and open it:

```sh
mkdir -p ~/Applications
cp -R dist/MenuOCR.app ~/Applications/
open ~/Applications/MenuOCR.app
```

Enable **Screen Recording** for MenuOCR in System Settings → Privacy & Security, then quit and reopen the app.

Press **⌘⇧O**, select some text, and paste with **⌘V**. Change the shortcut from the menu-bar settings.

For additional OCR languages:

```sh
brew install tesseract-lang
```

## Download

A prebuilt Apple Silicon app is available in [Releases](https://github.com/Hassaankh10/MenuOCR/releases/latest). It still requires `brew install tesseract`.

Unzip it, move MenuOCR to Applications, and open it. The download is not notarized; if macOS blocks it, use **Open Anyway** in Privacy & Security or build it locally.
