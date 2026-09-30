# MyHealthy

A native iPhone app for tracking blood pressure and medications for yourself and your family. Each person has their own profile with their own readings, medications, reminders, trends and doctor reports.

Built with SwiftUI, SwiftData and Swift Charts. No accounts, no server: health data stays on the iPhone.

## Features

**Profiles**
- Separate profiles for each person (name, date of birth and age, sex, height, weight, conditions, doctor).
- A personal blood pressure target for each profile (defaults to 135/85, the usual home-reading threshold).
- Morning and evening check reminders for each profile.
- Switch profiles from the avatar on the Today tab.

**Logging readings**
- Large number fields for systolic, diastolic and pulse.
- Optional second reading. The app saves the average, as home-monitoring guidelines recommend.
- Time of day (morning, afternoon, evening, night) is set from the clock and can be changed.
- Arm, position, quick tags (after coffee, stressed, missed a dose…) and notes.
- Shows right away whether a reading is within target. Very high readings (180/120 or above) get a safety notice.

**Medications**
- Search by name. Common blood pressure and cholesterol medications are built in and work offline. Anything else is looked up online:
  - names from [NLM RxNorm](https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html)
  - plain-language summaries and links from [MedlinePlus Connect](https://medlineplus.gov/medlineplus-connect/web-service/)
  - dosing, strengths and side effects from U.S. FDA drug labels via [openFDA](https://open.fda.gov/apis/drug/label/)
  - no API keys needed
- Each medication shows what it's for, how it works, typical adult doses, how to take it, side effects and when to get help, with a link to the source.
- Per-person schedule: strength, dose, 1–3 times a day, reminders, pills left and refill warning.
- Tap to mark doses as taken. Shows a 7-day view of doses taken and notices patterns such as "all missed doses were on Sundays".

**Trends and reports**
- Week, month, 3-month and year views: average, change since the first week, and a daily chart against the target.
- Morning vs. evening averages, share of readings in target, and the highest reading.
- Calendar of doses taken, with the adherence percentage.
- **Doctor report:** a multi-page PDF (summary, chart, medications with adherence, all readings) that you can share or print.

**Privacy**
- Optional Face ID / passcode lock.
- Data is stored on the device with SwiftData. Medication search sends only the typed name to the public services above.

Light and dark mode both follow the design: blue is always systolic, orange is always diastolic.

## Requirements

- Xcode 16 or later (the project uses Xcode 16 folder-synced groups)
- iOS 17 or later, iPhone

## Run it

1. Open `MyHealthy.xcodeproj` in Xcode.
2. Select the **MyHealthy** target → *Signing & Capabilities* → choose your Team. Change the bundle identifier (`com.princa.MyHealthy`) if needed.
3. Pick an iPhone simulator or your device and press **Run**.
4. On first launch, tap **Explore with Sample Data** to see four weeks of example readings and doses, or **Create a Profile** to start fresh. You can delete the sample profile from *Profiles* at any time (swipe left → Edit → Delete Profile).

New files added under `MyHealthy/` are picked up by Xcode automatically. You don't need to edit the project file.

## Project layout

```
MyHealthy/
  MyHealthyApp.swift          App entry, SwiftData container, notification delegate
  Core/                       Pure Swift logic (no UI): BP stats, targets, adherence,
                              label-text cleaning, built-in medication library
  Models/                     SwiftData models: Profile, BPReading, Medication, DoseLog
  Services/                   Drug info lookup, reminders, Face ID lock, sample data
  Design/                     Colors (light + dark), formatters, shared components
  Features/
    Root/                     Tabs, welcome screen, lock screen
    Today/                    Latest reading, today's doses, 7-day chart
    Log/                      New reading sheet
    Medications/              List, search, medication info + schedule
    Trends/                   Dashboard, chart, adherence calendar, all readings
    Report/                   Doctor report preview and PDF export
    Profiles/                 Profile list and editor
Tests/MyHealthyCoreTests/     Unit tests for Core
Package.swift                 Lets you run the Core tests with `swift test`
```

## Tests

The statistics, adherence and text-cleaning logic in `MyHealthy/Core` has no UI dependencies. To run its tests on a Mac:

```bash
swift test
```

## Ideas for next steps

- iCloud sync between devices (SwiftData + CloudKit, needs a paid developer account)
- Read and write blood pressure in Apple Health (HealthKit)
- "Mark as taken" straight from the reminder notification
- Home Screen widget with the latest reading and next dose
- Edit a saved reading

## Disclaimer

MyHealthy is a personal tracking tool, not a medical device. Medication information is general reference only. Always follow the dose on your prescription label and your doctor's advice. For a very high reading with symptoms such as chest pain, shortness of breath, weakness or trouble speaking, call 911.
