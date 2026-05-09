# Miles — Personal iOS Mileage Tracker

A simple iOS app to track mileage for IRS reimbursement. Built for personal use on iPhone.

## Features

- **Log trips** with date, purpose, origin/destination addresses, and notes
- **Auto-calculate distance** via MapKit driving directions, with manual override
- **Round trip support** — doubles the distance automatically
- **Quarterly grouping** — calendar quarters (Q1–Q4) with totals and paid status
- **Export per quarter** — CSV, Markdown, and PDF with totals and consistent rounding
- **Address autocomplete** — real-time MapKit suggestions for places and addresses
- **Frequent destinations** — save and auto-suggest with a default starting place
- **IRS rate lookup** — checks current year's rate from IRS.gov with hardcoded fallback
- **Full database backup** — export/import all data as JSON
- **Editable trips** — tap any trip to view or edit

## Build & Run

- macOS with Xcode 16+
- Open `Miles/Miles.xcodeproj`, select a simulator or device, press Cmd+R
- iOS 17+ deployment target
- No external dependencies (SwiftUI, SwiftData, MapKit only)

## ⚠️ Vibecoding Disclosure

This app was built primarily through AI-assisted development ("vibecoding") using opencode powered by DeepSeek. While every effort has been made to ensure correctness, this software has not undergone formal testing or code review by a professional iOS developer.

- No unit tests have been implemented
- No accessibility audit has been performed
- No performance profiling has been done
- Edge cases may not be fully handled

**Use at your own risk.** This app handles mileage data used for tax reimbursement — verify all calculations against official IRS rates and your own records before filing.

## Attribution

All commits were co-authored with opencode AI. Development occurred between 2025-2026. This project exists as a personal tool and is shared publicly for reference and transparency.

## License

MIT
