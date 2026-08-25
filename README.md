# BrickDrop

BrickDrop is a small, native SwiftUI app for importing ROMs onto a TRIMUI Brick Pro SD card from macOS. Drop files or whole folders, review where every file will go, resolve any ambiguous formats, and then import. BrickDrop removes the Finder metadata that can otherwise appear as duplicate games in the stock launcher.

## What it does

- Large drag-and-drop target for files and folders
- Always previews the route and destination before copying
- Remembers the selected mounted SD card using a security-scoped bookmark
- Copies into the stock `Roms/<SYSTEM>` folder layout
- Uses extensions plus file and source-folder names to resolve ambiguous formats
- Requires an explicit system choice when heuristics are not confident
- Preserves the relative structure of dropped folders
- Reads `.cue` files and automatically includes referenced track files
- Supports `.m3u` multi-disc playlists and their referenced files
- Removes AppleDouble `._*`, `.DS_Store`, and known macOS volume metadata using native filesystem APIs
- Shows per-file status, destination, skips, and failures
- Leaves existing destination files unchanged unless **Replace existing files** is enabled

BrickDrop does not invoke `dot_clean` or any other shell command while importing or cleaning.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later with the macOS SDK
- A mounted TRIMUI Brick Pro SD card with, or ready to receive, a `Roms` directory

## Build and run

### Xcode

1. Clone the repository.
2. Open `Package.swift` in Xcode.
3. Select the **BrickDrop** scheme and **My Mac** destination.
4. Press **Run**.

### Terminal

```sh
swift run BrickDrop
```

Run the tests with:

```sh
swift test
```

To produce a conventional Apple-silicon-only `BrickDrop.app` bundle in `dist/`:

```sh
./scripts/build-app.sh
```

The local app bundle is ad-hoc signed. Distributing it to other Macs requires your own Apple Developer signing and notarization workflow.

## How to use

1. Insert and mount the Brick Pro SD card.
2. Click **Choose SD Card…** and select the root of the mounted card, not its `Roms` folder.
3. Drop ROM files or folders onto the large target.
4. Review the preview. For an ambiguous file such as a generic `.chd`, `.bin`, `.iso`, or archive, choose its system.
5. Click **Import**. BrickDrop copies the files, then removes macOS metadata from the card.
6. Eject the card normally and refresh ROMs on the device if needed.

**Clean Metadata Now** can be used without importing. It scans the selected SD card and removes only known metadata names; it does not delete ordinary hidden files or ROM formats.

## Stock folder mappings

| Formats / hints | Destination |
| --- | --- |
| `.nes`, `.fds` | `Roms/FC` |
| `.sfc`, `.smc` | `Roms/SFC` |
| `.gb` | `Roms/GB` |
| `.gbc` | `Roms/GBC` |
| `.gba` | `Roms/GBA` |
| `.n64`, `.z64`, `.v64` | `Roms/N64` |
| `.nds` | `Roms/NDS` |
| `.gg` | `Roms/GG` |
| `.md`, `.gen`, `.smd` | `Roms/MD` |
| `.sms` | `Roms/MS` |
| `.pce` | `Roms/PCE` |
| `.cue`, `.pbp`; `.bin` with a CUE companion | `Roms/PS` |
| `.gdi`, `.cdi` | `Roms/DC` |
| `.cso` | `Roms/PSP` |
| `.neo` | `Roms/NEOGEO` |
| Arcade/MAME filename or source-folder hints | `Roms/ARCADE` |

Ambiguous `.chd`, `.bin`, `.iso`, `.img`, `.m3u`, `.zip`, and `.7z` files are routed from source-folder and filename hints when possible. Otherwise BrickDrop pauses them for a system choice. For example, a CHD from a folder named `Dreamcast` routes to `Roms/DC`; an unlabelled CHD offers PlayStation, Dreamcast, and PC Engine.

## Disc sets and folders

- Dropping a folder preserves that folder and all supported nested paths under the chosen system folder. This is the preferred way to import multi-disc collections.
- Dropping a `.cue` directly reads its `FILE` entries and includes referenced tracks. Those files are placed in one game subfolder so the set stays together.
- Dropping an `.m3u` directly includes existing relative paths listed by the playlist.
- Missing references are never invented or silently replaced. Verify the preview contains every expected disc or track before importing.
- Descriptor formats can vary. Unusual CUE quoting, absolute playlist paths, compressed archives containing mixed systems, and emulator-specific layouts may need manual preparation.

## Metadata cleanup and safety

BrickDrop removes these known macOS artifacts from the selected SD card:

- Files beginning with `._` (AppleDouble metadata)
- `.DS_Store` and `.VolumeIcon.icns`
- `.Spotlight-V100`, `.Trashes`, `.fseventsd`, `.TemporaryItems`, and `.DocumentRevisions-V100` metadata directories

The cleaner does not follow symbolic links and does not delete files merely because they are hidden. Imports preview first, default to no overwrite, and report every copy result. Even so, keep a backup of an SD card that contains saves or files you cannot replace, and confirm that the selected root is the intended removable card before cleaning.

## Limitations

- Routing is based on the common Brick Pro stock folder layout. Custom firmware may use different folder names.
- BrickDrop identifies formats; it does not validate ROM integrity, decrypt files, extract archives, or convert disc images.
- A format alone cannot always identify a system. The app deliberately asks instead of guessing when confidence is low.
- The app does not edit launcher configuration or refresh the device-side ROM database.
- macOS can recreate some volume metadata after cleanup; importing immediately before ejecting minimizes this.

## Development

The routing, disc-set planning, and metadata safety behavior are covered by XCTest tests in `Tests/BrickDropTests`.

```sh
swift build
swift test
```

## License

MIT — see [LICENSE](LICENSE).
