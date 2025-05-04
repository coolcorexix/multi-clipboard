# MultiClipboard

A modern, privacy-friendly clipboard manager for macOS. MultiClipboard keeps track of your recent clipboard history (text, images, files, and videos), lets you search and preview past items, and quickly paste them again—all with a beautiful, keyboard-driven interface.

---

## Features

- **Automatic Clipboard History**: Remembers your last clipboard items (text, images, files, videos).
- **Search & Filter**: Instantly search your clipboard history by content, type, or alias.
- **Quick Paste**: Use keyboard shortcuts to open the search panel and paste items.
- **Image & File Previews**: See thumbnails for images and file details in your history.
- **Aliases**: Assign custom names to clipboard items for easier recall.
- **Privacy-First**: All data is stored locally in `~/Library/Application Support/com.multiclipboard/clipboard_history.json`.
- **No Cloud, No Ads, No Tracking**.

---

## Installation

### Prerequisites
- macOS 13.0 or later
- [Swift 5.7+ toolchain](https://swift.org/download/)

### Build & Run (Command Line)

1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd multi-clipboard
   ```
2. **Build the app:**
   ```sh
   ./build.sh
   ```
   The app bundle will be created at `build/MultiClipboard.app`.
3. **Move to Applications:**
   Drag `build/MultiClipboard.app` to your `/Applications` folder.

### Build & Run (Xcode)

1. **Generate Xcode project:**
   ```sh
   ./generate-xcode-project.sh
   ```
2. **Open in Xcode:**
   Open `MultiClipboard.xcodeproj` and build/run as usual.

---

## Usage

- **Start the app** from your Applications folder. A clipboard icon will appear in your menu bar.
- **Clipboard history** is automatically recorded as you copy new items.
- **Open the search panel** with <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>V</kbd> (customizable in code).
- **Navigate** results with arrow keys, <kbd>Enter</kbd> to paste, <kbd>Esc</kbd> to close.
- **Assign aliases** to items for easier searching.
- **Show full history window** from the menu bar or with <kbd>Cmd</kbd> + <kbd>H</kbd>.

### Keyboard Shortcuts

| Shortcut                | Action                        |
|-------------------------|-------------------------------|
| Cmd + Shift + V         | Open search panel             |
| Cmd + H                 | Show history window           |
| Esc                     | Close search/history panel    |
| ↑ / ↓                   | Navigate results              |
| Enter                   | Copy selected item to clipboard |

---

## Permissions

To enable advanced features (like reading selected text from other apps), grant Accessibility permissions:

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button and add `MultiClipboard.app`
3. Enable the toggle for MultiClipboard

The app will prompt you if permissions are missing.

---

## Storage & Privacy

- Clipboard history is stored locally at:
  `~/Library/Application Support/com.multiclipboard/clipboard_history.json`
- Images and files are stored in:
  `~/Library/Application Support/com.multiclipboard/ClipboardData/`
- No data ever leaves your device.

---

## Troubleshooting

- **App not recording clipboard?**
  - Make sure Accessibility permissions are granted.
  - Try restarting the app after granting permissions.
- **Search panel not opening?**
  - Ensure the app is running (menu bar icon visible).
  - Check for conflicting keyboard shortcuts.
- **Build issues?**
  - Make sure you have Swift 5.7+ and macOS 13.0+.

---

## Contributing

Pull requests and issues are welcome! Please open an issue for bugs or feature requests.

---

## License

MIT License. See [LICENSE](LICENSE) for details. 