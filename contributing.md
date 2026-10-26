# Contributing To Juicer

Thank you for your interest in contributing to Juicer! As an open-source utility, we welcome all developer improvements.

## Development Setup

To build and run the Juicer project locally:

1. **Prerequisites**: Make sure you have Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:

   ```bash
   brew install xcodegen
   ```

2. **Generate Xcode Project**: Generate the project file from our declarative specification (`project.yml`):

   ```bash
   xcodegen generate
   ```

3. **Open Xcode**: Open the generated project bundle:

   ```bash
   open juicer.xcodeproj
   ```

4. **Compile & Run**: Press `Cmd + R` inside Xcode to build and launch the application locally.

## Guidelines

- **File/Folder Naming**: All files and folders in the repository should be strictly named in **lowercase**.
- **Commit Messages**: Strictly adhere to the canonical commit structure `xxx: xxx xxx xxx` (prefix + exactly three lowercase words, e.g. `feat: add menu item`, `fix: resolve timing warning`, `refactor: extract modular view`).
- **Tests**: Verify your changes build cleanly and run unit tests (`Cmd + U` in Xcode) before opening a Pull Request.

Please make sure to read and follow our [Code Of Conduct](code_of_conduct.md) before submitting contributions.
