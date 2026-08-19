Windows build requirements:

- 64-bit JDK 21 or newer, with javac, jar and jpackage available
- Inno Setup 6 or 7 (https://jrsoftware.org/isdl.php) for the installer

Normal build, produces dist\NoteBot-Setup-<version>.exe:

powershell -NoProfile -ExecutionPolicy Bypass -File .\_SETUP\Windows\build.ps1

Add -Portable to also produce dist\NoteBot-Portable-<version>.zip. The portable
edition keeps its notes inside its own data folder instead of %LOCALAPPDATA%.

The script compiles the source directly, builds the application image with
jpackage, verifies that the packaged JAR matches the compiled one and then runs
Inno Setup. Output files are written to the dist folder in the repository root.

The installer runs without administrator rights and installs into
%LOCALAPPDATA%\Programs\NoteBot. If a previous NoteBot installed for all users is
detected, the installer offers to remove it first. Notes are never touched by an
install or an uninstall.
