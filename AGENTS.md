# Miles — iOS Mileage Tracker

## Stack
- SwiftUI + SwiftData (iOS 17+), MapKit, MVVM pattern
- No external dependencies beyond Apple frameworks

## Data Model
- `Trip`: date, purpose, distanceMiles, isRoundTrip, rateCentsPerMile, originAddress, destinationAddress, notes, optional FrequentDestination link
- `FrequentDestination`: name, address
- `Quarter`: computed from trip dates (calendar quarters Q1–Q4), paid status stored as key-value

## Commands
- Run: Open `Miles.xcodeproj` in Xcode, run on simulator/device
- No build tools, no test framework configured yet

## Key Design Decisions
- Distance calculated via MapKit MKDirections; user can override manually
- IRS rate stored per-trip (never changes retroactively); auto-lookup on app launch / Settings appear
- 3-tab nav: Trips / Quarters / Settings
- Export by quarter: CSV / Markdown / PDF via system share sheet
- Rounding: dollars to 2dp, miles to 1dp; totals computed from rounded values
