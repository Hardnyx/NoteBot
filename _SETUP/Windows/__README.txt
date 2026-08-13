Windows build requirements:

- JDK 21 or newer, with jpackage available
- Maven 3.9 or newer
- Inno Setup 6 for the installer

Run build.ps1 from PowerShell. It compiles the project, creates a portable
application with its own Java runtime, and then builds the installer when
Inno Setup is available.

Output files are written to the dist folder in the repository root.
