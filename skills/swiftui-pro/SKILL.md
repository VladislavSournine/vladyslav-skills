---
name: swiftui-pro
description: Use when reviewing SwiftUI code. Checks best practices, modern APIs, maintainability, and performance.
license: MIT
metadata:
  author: Paul Hudson (adapted for vladyslav-skills)
  version: "1.0"
  source: https://github.com/twostraws/SwiftUI-Agent-Skill
---

**Type:** Architect

Review Swift and SwiftUI code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems — do not nitpick or invent issues.

## Review process

1. Check for deprecated API using `references/api.md`.
2. Check that views, modifiers, and animations have been written optimally using `references/views.md`.
3. Validate that data flow is configured correctly using `references/data.md`.
4. Ensure navigation is updated and performant using `references/navigation.md`.
5. Ensure the code uses designs that are accessible and compliant with Apple's Human Interface Guidelines using `references/design.md`.
6. Validate accessibility compliance including Dynamic Type, VoiceOver, and Reduce Motion using `references/accessibility.md`.
7. Ensure the code is able to run efficiently using `references/performance.md`.
8. Quick validation of Swift code using `references/swift.md`.
9. Final code hygiene check using `references/hygiene.md`.
10. Cross-check against the Apple HIG compact checklist (layout, nav, a11y, color, components) using `references/ios-hig.md`.

If doing a partial review, load only the relevant reference files.


## Core Instructions

- iOS 26 exists, and is the default deployment target for new apps.
- Target Swift 6.2 or later, using modern Swift concurrency.
- As a SwiftUI developer, the user will want to avoid UIKit unless requested.
- Do not introduce third-party frameworks without asking first.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Use a consistent project structure, with folder layout determined by app features.


## Output Format

Organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated (e.g., "Use `foregroundStyle()` instead of `foregroundColor()`").
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.


## References

- `references/accessibility.md` — Dynamic Type, VoiceOver, Reduce Motion, and other accessibility requirements.
- `references/api.md` — updating code for modern API, and the deprecated code it replaces.
- `references/design.md` — guidance for building accessible apps that meet Apple's Human Interface Guidelines.
- `references/hygiene.md` — making code compile cleanly and be maintainable in the long term.
- `references/navigation.md` — navigation using `NavigationStack`/`NavigationSplitView`, plus alerts, confirmation dialogs, and sheets.
- `references/performance.md` — optimizing SwiftUI code for maximum performance.
- `references/data.md` — data flow, shared state, and property wrappers.
- `references/swift.md` — tips on writing modern Swift code, including using Swift Concurrency effectively.
- `references/views.md` — view structure, composition, and animation.
