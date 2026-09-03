# DadaFinanza

Private-first personal finance app built with Flutter.

## Goals

- Fast expense/income capture with a strong one-handed mobile flow.
- Multiple accounts, transfers, categories, tags, notes and optional receipt photos.
- Local SQLite storage: financial data stays on-device by default.
- Recurring payments/reminders and useful monthly analytics.
- Android home-screen widget for balance visibility and one-tap quick expense entry.

## UX direction

The first version is intentionally dashboard-first: balance, monthly cash flow, budget status and recent transactions are visible without opening secondary menus. Quick Add is always one tap away. Advanced areas (accounts, charts, recurring payments, categories and settings) remain available from the bottom navigation / More sheet instead of occupying the primary screen.

## Android widget

The Android widget displays the current total balance and shortcuts for common expense categories. Tapping a category launches the Quick Add screen with that category already selected. Widget data is synchronized through `home_widget`.

## Status

Initial Flutter/Android implementation in progress.
