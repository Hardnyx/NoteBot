# NoteBot

NoteBot is a lightweight desktop sticky-notes application. It has no account, synchronization, telemetry or automatic updater.

This fork keeps the original interface and storage format while updating the application for current Windows and Java releases.

## Changes in version 1.8.0

### Fixed

- Resizing a note no longer collapses it. The size limit used during a drag came from
  `GraphicsEnvironment.getMaximumWindowBounds()`, which describes only the work area of
  the primary monitor and whose origin was discarded. A note on a monitor placed to the
  right of the primary one, or one sitting low enough to overlap the taskbar, produced a
  negative limit that overrode the minimum size and drove the window to zero pixels.
- The collapsed size was then saved, so the note reopened as a one-pixel sliver on the
  next launch. Notes are now clamped to a usable minimum both while resizing and while
  reading the stored file, which also repairs files written by earlier versions.
- A failure while building the interface no longer looks like nothing happened. The
  event dispatch thread prints its exceptions to a stream that does not exist in a
  windowed application, so startup is now wrapped and reported.
- Saving is serialised. `saveState` already guarded the note list, but two threads could
  still enter the file rotation at the same time. It is now synchronised as a whole.
- Saving no longer fails when another program is holding the notes file. Windows refuses
  to move or replace an open file, so a synchronisation client, an antivirus scanner or
  the search indexer could make a save fail with a sharing violation. The backup
  generations are now copied instead of moved, which keeps `sticky.dat` in place for the
  whole save, a failure while rotating the backups is logged instead of aborting the
  save, and replacing the notes file is retried for a few hundred milliseconds.

### Added

- A pin button in the note bar keeps a note above other windows. The state is shown by
  the button, is also available from the bar's right-click menu and from `Ctrl+T`, and
  is stored with the note.
- A **Text size** entry in the bar's right-click menu opens a dialog with a slider and a
  numeric field, so any zoom level inside the allowed range can be chosen directly.
- The zoom limits are now derived from the display instead of being fixed. The lower
  limit keeps the text at roughly five points so a note can never become blank, and the
  upper limit keeps a line of text within about a third of the shortest side of the
  smallest monitor. `Ctrl` with the mouse wheel and `Ctrl` with plus and minus now move in
  proportional steps, and `Ctrl+0` restores the default size.

### Changed

- The installer no longer requires administrator rights. It installs into
  `%LOCALAPPDATA%\Programs\NoteBot`, registers the optional startup entry under the
  current user instead of the whole machine, and skips the folder, group and
  confirmation pages. An earlier all-users installation is detected and removed first.
- `build.ps1` produces the installer alone by default. The portable folder is built
  only when `-Portable` is passed.

## Changes in version 1.7.3

- Uses the first non-empty line of each note as its Windows title.
- Updates the title while the note is edited, making multiple notes easy to distinguish in window-management tools.
- Uses a localized `Empty note - NoteBot` title when a note has no text.
- Limits the content preview to 40 characters without changing the saved-note format.
- Extends text zoom from 400% to 800%.

## Changes in version 1.7.2

- Fixes the resize event that could stop the application during startup.
- Keeps the single-instance lock open for the full lifetime of the application.
- Brings the notes to the front after a normal launch.
- Reports startup and storage errors instead of closing silently.
- Restores notes to a visible monitor when the screen layout changes.
- Saves through a temporary file and keeps two backup generations.
- Preserves unreadable data files in a dated recovery folder.
- Uses the same direct `javac` build for local tests and Windows packages.
- Produces a self-contained installer and a genuinely portable folder with its own data directory.

The installed edition keeps existing notes in:

```text
%LOCALAPPDATA%\NoteBot\sticky.dat
```

The portable edition keeps them inside its own `NoteBot\data` folder.

## Test from VS Code or PowerShell

Install a 64-bit JDK 17 or newer. No Java IDE and no Maven installation are required for this route.

Open the repository folder in VS Code, open its PowerShell terminal and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\_SETUP\Windows\run-local.ps1
```

The script compiles the current source, copies the resources, creates `target\NoteBot-1.8.0.jar` and opens it with isolated test data under `.local-run\data`.

To test with the real notes stored in `%LOCALAPPDATA%`, add `-UseRealData`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\_SETUP\Windows\run-local.ps1 -UseRealData
```

Maven remains supported as an alternative:

```text
mvn clean package
java -jar target/NoteBot-1.8.0.jar
```

## Run the regression checks

The checks in `StickyNotes\test` cover the behaviour that used to collapse a note, the
zoom limits, the pin state and the storage round trip. They run against a temporary data
folder under `.local-run\test-data`, so the real notes are never touched.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\_SETUP\Windows\run-tests.ps1
```

The script prints one line per check and fails if any of them does. The test sources are
not part of the application JAR.

One of the checks makes the backup file impossible to write to on purpose, so a stack
trace for `The note backups could not be rotated` in the output is expected and is
followed by `PASS`.

Keeping the repository inside a folder synchronised by OneDrive, Dropbox or a similar
client is not recommended. The client competes for `target`, for the test data folder and
later for `.git`.

## Build the Windows packages

The simplest way is to double-click `compile.bat` in the repository root. It removes the
mark of the web from the extracted files, compiles, asks whether to run the regression
checks and builds the installer, then waits so the output stays readable.

The checks open and close note windows on screen for a few seconds, which is distracting
while working, so answering `n` skips them. Pressing Enter runs them. What gets built is
the same either way. Any argument the batch receives is passed to `build.ps1`, so
`compile.bat -Portable` also produces the portable ZIP, and passing `-SkipTests` skips the
question altogether.

Use a JDK that includes `jpackage` (JDK 21 is recommended) and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\_SETUP\Windows\build.ps1
```

The script compiles the source itself and writes these files to `dist`:

- `NoteBot-Setup-1.8.0.exe`

Add `-Portable` to also produce `NoteBot-Portable-1.8.0.zip`. Add `-SkipTests` to package
without running the checks first, and `-IsccPath` to point at a copy of Inno Setup that the
automatic search does not find.

Every build writes `dist\SHA256SUMS.txt` next to the packages.

The portable ZIP must be extracted completely. `NoteBot.exe` depends on the adjacent `app` and `runtime` folders and must not be copied by itself.

The installer is a single file. It runs without administrator rights, installs into
`%LOCALAPPDATA%\Programs\NoteBot`, and adds Start menu and uninstall entries. A desktop
icon and starting NoteBot when you sign in are offered as tasks. If a NoteBot installed
for all users by version 1.7.x or earlier is found, the installer offers to remove it
first; your notes are stored separately and are not affected.

The GitHub Actions workflow runs the same script. Its result is available at the bottom of a completed workflow run under the `NoteBot-Windows` artifact. For public downloads, attach the installer and portable ZIP from `dist` to a GitHub Release; **Code > Download ZIP** only downloads the source.

The generated executables are not digitally signed. Avoiding Windows SmartScreen reputation warnings on public releases requires a code-signing certificate.

## Usage

- Drag the upper part of a note to move it.
- Drag an edge or corner to resize it.
- Use `Ctrl+N` to create a note and `Ctrl+D` to delete one.
- Use `Ctrl` with the mouse wheel, or `Ctrl` with plus and minus, to change the text size. `Ctrl+0` restores the default size.
- Right-click the upper part of a note and choose **Text size** to pick an exact zoom level. The range shown in that dialog is calculated from your screen: the lower end keeps the text readable and the upper end keeps a line of text within about a third of the screen.
- Click the pin button in the note bar, or press `Ctrl+T`, to keep a note above other windows. The setting is remembered per note.
- The first non-empty line becomes the Windows title of the note and is shortened to 40 characters.
- Right-click the text for editing commands.
- Right-click the upper part of a note to change its color or open the About window.

## Signing, SmartScreen and antivirus warnings

An unsigned installer downloaded from the internet triggers a SmartScreen warning, and some
antivirus engines report a generic detection for it. This is about reputation, not about
the contents of the file: a new executable that nobody has downloaded before starts with no
reputation at all.

What this project already does to stay out of the generic-detection buckets:

1. The installer carries complete metadata

Publisher, copyright, description, version, support and update URLs, and a real uninstall
entry. An installer that describes itself fully looks less like a dropper.

2. The installer never asks for administrator rights

It installs per user and its manifest requests `asInvoker`. Silent elevation is one of the
strongest heuristic signals.

3. Starting with Windows is unchecked by default

Writing to the `Run` key without being asked is both a surprise for the user and a common
trigger.

4. Every build publishes SHA-256 checksums

Anyone can confirm that the file they downloaded is the file that was built.

What actually removes the warning is a code signing certificate. Once you have one as a
`.pfx` file, the build signs both the application and the installer:

```powershell
.\_SETUP\Windows\build.ps1 -SignPfx C:\ruta\certificado.pfx
```

The password is requested interactively and the signature is timestamped, so it stays valid
after the certificate expires. Reputation still builds up over the first downloads, and it
accrues to the certificate rather than to each individual file, so later releases inherit
it.

If an antivirus reports a false positive, it can be submitted for review at
`https://www.microsoft.com/en-us/wdsi/filesubmission` for Microsoft Defender, and most other
vendors have an equivalent form.

## Credits and license

NoteBot was created by Federico Dossena and originally published at [adolfintel/NoteBot](https://github.com/adolfintel/NoteBot).

Version 1.7.x and 1.8.x are maintained by Alonso Roman. The original copyright notices remain in place and modified files identify the later contribution separately.

Copyright (C) 2016-2020 Federico Dossena  
Modifications Copyright (C) 2026 Alonso Roman

NoteBot is distributed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
