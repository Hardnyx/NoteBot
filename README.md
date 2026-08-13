# NoteBot

NoteBot is a lightweight desktop sticky-notes application. Notes are stored locally, there is no account, synchronization, telemetry or automatic updater.

This fork keeps the original interface and storage format while updating the parts that no longer worked reliably on current versions of Windows.

## Changes in version 1.7

- Uses a current Java runtime instead of the bundled 32-bit Java 7 release.
- Keeps the single-instance lock open for the full lifetime of the application.
- Reports startup and storage errors instead of closing silently.
- Restores notes to a visible monitor when the screen layout changes.
- Saves through a temporary file and keeps two backup generations.
- Preserves unreadable data files in a dated recovery folder.
- Builds a self-contained Windows application with `jpackage`.

Existing notes remain in the same location and use the same serialized format:

```text
%LOCALAPPDATA%\NoteBot\sticky.dat
```

## Build from source

Requirements:

- JDK 17 or newer
- Maven 3.9 or newer

Build and run the JAR:

```text
mvn clean package
java -jar target/NoteBot-1.7.0.jar
```

To create the Windows portable package and installer, use a JDK that includes `jpackage` and run:

```powershell
.\_SETUP\Windows\build.ps1
```

Inno Setup 6 is required for the installer. If it is not installed, the script still creates the portable package. The GitHub Actions workflow builds both automatically on Windows.

The generated files are not digitally signed. Avoiding Windows reputation warnings on public releases requires a code-signing certificate; this cannot be solved only by changing the source code.

## Usage

- Drag the upper part of a note to move it.
- Drag an edge or corner to resize it.
- Use `Ctrl+N` to create a note and `Ctrl+D` to delete one.
- Use `Ctrl` with the mouse wheel to change the text size.
- Right-click the text for editing commands.
- Right-click the upper part of a note to change its color or open the About window.

## Credits and license

NoteBot was created by Federico Dossena and originally published at [adolfintel/NoteBot](https://github.com/adolfintel/NoteBot).

Version 1.7 is maintained by Alonso Roman. The original copyright notices remain in place and modified files identify the later contribution separately.

Copyright (C) 2016-2020 Federico Dossena  
Modifications Copyright (C) 2026 Alonso Roman

NoteBot is distributed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
