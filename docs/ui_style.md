# UI Style Guide

This is a lightweight reference for keeping Toothfile screens and dialogs consistent.

## Theme

The app uses Material 3 themes with a blue seed color:

- Primary seed: `#2563EB`

Dark mode is enabled via `ThemeData(... brightness: Brightness.dark ...)`.

See: [main.dart](file:///c:/Users/stard/OneDrive/Desktop/toothfile/lib/main.dart#L206-L219)

## Visual patterns used in the app

- **Rounded surfaces**: cards/sheets commonly use 12–16px radius.
- **Primary CTA**: often uses a blue → purple gradient when the design calls for emphasis.
- **Dialogs/Sheets**: prefer bottom sheets for settings and quick actions; keep content compact and consistent with other tabs.

## Text and labels

- Prefer short, action-oriented labels: “Save”, “Remove”, “Send”, “Open”.
- For private info (like email), follow the masking rule from [profile.md](profile.md).

## Do / Don’t

- Do keep layout stable when changing dark-mode colors (only colors, not spacing/structure).
- Don’t embed routing metadata into user-visible fields (e.g., don’t put device routing markers into `message`).

