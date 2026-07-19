# FlexomBar

A macOS menu bar app for [Flexom](https://www.bouyguestelecom.fr/flexom) (Bouygues) homes:
control lights and shutters ("volets") from the menu bar, filter by room, and drive everything
with Siri or the Shortcuts app.

Built on [swift-overkiz-api](https://github.com/phimage/swift-overkiz-api), the Swift client for
the Overkiz platform that powers Flexom.

> **Disclaimer**: This is an independent, unofficial project. It is not affiliated with,
> endorsed by, or sponsored by Bouygues Telecom, Flexom, Somfy, or Overkiz. "Flexom" and any
> related names/trademarks belong to their respective owners and are used here only to describe
> interoperability. The software is provided "as is", without warranty of any kind; use it at
> your own risk and see the [LICENSE](LICENSE) for details.

## Features

- **Menu bar panel** — lights (on/off, brightness when dimmable) and shutters
  (open / stop / close, position slider) grouped by room, with a room filter.
- **Live updates** — the panel polls the Overkiz event stream while open, so changes made from
  wall switches or the Flexom app show up.
- **Siri & Shortcuts** — App Intents with French and English phrases:
  - « Dis Siri, allume *Lampe salon* avec FlexomBar »
  - « Dis Siri, ferme les volets avec FlexomBar »
  - « Dis Siri, éteins les lumières avec FlexomBar »
  - Room-scoped variants are available in the Shortcuts app (open/close all shutters in a room,
    turn off all lights in a room, set brightness or shutter position).
- **Credentials in the Keychain** — the password never touches disk in clear text; the app is
  sandboxed with network-client as its only entitlement.

## Building

Requirements: Xcode 16+ (the project targets macOS 14).

```bash
brew install xcodegen        # once
xcodegen generate            # produces FlexomBar.xcodeproj from project.yml
open FlexomBar.xcodeproj     # build & run from Xcode…
```

or from the command line:

```bash
xcodebuild -project FlexomBar.xcodeproj -scheme FlexomBar -configuration Release build
```

The project file is generated — edit `project.yml`, not the `.xcodeproj`.

The default signing is ad-hoc (`CODE_SIGN_IDENTITY: "-"`), which is enough to run locally and to
register the Siri shortcuts with the system. For distribution, set your team in `project.yml`.

## First run

1. Launch the app — a house icon appears in the menu bar.
2. Click it and sign in with your Flexom e-mail and password
   (the same credentials as the Flexom v3 iOS app).
3. Devices appear grouped by room. Siri phrases become available shortly after the first
   successful connection (the system indexes device and room names from the app).

## Notes

- Siri needs the app to have run at least once; intents launched while the app is closed will
  start it in the background and connect with the stored credentials.
- The Overkiz API rate-limits bulk loads (one setup fetch per day per session is the documented
  budget); the app fetches the setup once per connection and relies on events afterwards, so
  use "Actualiser" sparingly.
- Only lights and shutter-like devices are shown. Everything else in the setup (sensors,
  heating, …) is ignored for now.
