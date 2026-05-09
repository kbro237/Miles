# Mileage Tracker — Design Spec

## Overview

A personal iOS mileage tracking app built with SwiftUI + SwiftData. Enter trips with dates, addresses, and purpose; the app calculates distance via MapKit and groups trips into calendar quarters for IRS mileage reimbursement tracking. Export by quarter to CSV, Markdown, and PDF.

## Architecture

- **Framework:** SwiftUI (iOS 17+), SwiftData for persistence
- **Pattern:** MVVM — views observe @Observable model objects
- **Platform:** iOS only (personal app, no distribution)
- **Dependencies:** MapKit (geocoding + distance calculation), `UIActivityViewController` (export sharing)

## Data Model

### Trip
| Field | Type | Notes |
|---|---|---|
| date | Date | No time component |
| purpose | String | e.g. "Client meeting" |
| distanceMiles | Double | Auto-calculated from Maps or manual entry |
| isRoundTrip | Bool | If true, distance is doubled |
| rateCentsPerMile | Int | IRS rate at time of trip (in cents) |
| originAddress | String | Full street address |
| destinationAddress | String | Full street address |
| notes | String? | Optional |
| destination | FrequentDestination? | Optional relationship |

### FrequentDestination
| Field | Type | Notes |
|---|---|---|
| name | String | "Home", "Office", etc. |
| address | String | Full street address |

### Quarter
Not a stored entity — computed from trip dates as calendar quarters (Q1: Jan–Mar, Q2: Apr–Jun, Q3: Jul–Sep, Q4: Oct–Dec). Paid status stored as key-value store keyed by "YYYY-Q#".

## Navigation (3 Tabs)

1. **Trips** — List of all trips, newest first. Tap to view/edit. "+" to add. Swipe to delete.
2. **Quarters** — List of quarter summaries (year, quarter, total miles, total reimbursement, paid status). Tap for trip detail. Export button. Mark as paid toggle.
3. **Settings** — Current IRS rate display + "Check Current Rate" button. Default origin address. Manage frequent destinations.

## Distance Calculation

- On trip entry, when origin and destination addresses are filled, call MapKit `MKDirections` API on background queue
- Calculate driving distance in miles, populate distance field
- User can manually override the distance by typing
- Round trip checkbox doubles the distance
- If offline or lookup fails, user enters miles manually

## IRS Rate Lookup

- On app launch and Settings view appear, attempt to fetch current IRS mileage rate
- Rate stored per-trip at time of entry (never changed retroactively)
- If lookup fails, use last known rate from user's manual entry
- Rate is editable in case lookup is wrong

## Export (per quarter)

- Action sheet: CSV / Markdown / PDF
- **CSV:** Columns — date, origin, destination, distance, rate, reimbursement, purpose. Totals row.
- **Markdown:** Formatted table with totals row for miles and dollar amount
- **PDF:** Render SwiftUI summary view via `UIGraphicsPDFRenderer`
- All exports include: total miles, total reimbursement, consistent rounding (2 decimal places)
- Share via system share sheet (AirDrop, Mail, etc.)

## Rounding Convention

All dollar amounts rounded to 2 decimal places. All distance values rounded to 1 decimal place. Totals are computed from rounded individual values.
