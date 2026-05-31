# CarLoan

iOS app for tracking car loan installments. Built with SwiftUI and SwiftData.

## Features

- **Multiple financings** — manage more than one car loan at once
- **Price (French) amortization table** — auto-generated on financing creation
- **Dashboard** — progress bar, amounts paid/remaining, next installment countdown
- **Installment list** — filter by all / paid / open / overdue
- **Mark as paid** — record real payment date and amount; optional receipt photo attachment
- **Receipt photos** — attach images from the gallery; view full-screen; delete per image
- **Report** — summary of paid/remaining amounts with interest breakdown
- **Send Report** — export as PDF or PNG image and share via WhatsApp, AirDrop, email, etc.
- **Early payoff simulation** — see interest saved and new payoff date
- **Reminders** — configurable push notifications before due dates (1, 3 or 7 days)
- **Export / Import** — JSON backup with receipts embedded as base64; share via Files, iCloud Drive, AirDrop
- **Schema migrations** — SwiftData `VersionedSchema` + `SchemaMigrationPlan`; data survives app updates
- **Localization** — English and Portuguese (pt-BR), respects device language

## Requirements

- Xcode 16+
- iOS 17+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
git clone <repo-url>
cd carloan
xcodegen generate
open CarLoan.xcodeproj
```

Set your Development Team in Xcode (Signing & Capabilities) before running on a real device.

## Project structure

```
CarLoan/
├── CarLoanApp.swift              # App entry point + ModelContainer
├── Database/
│   ├── SchemaV1.swift            # VersionedSchema v1
│   └── MigrationPlan.swift       # SchemaMigrationPlan — add stages here on model changes
├── Models/
│   ├── Financing.swift
│   ├── Installment.swift
│   └── Payment.swift
├── Services/
│   ├── LoanCalculator.swift      # Price table & early payoff
│   ├── ImageStorageService.swift # Receipt images in Documents/receipts/
│   ├── NotificationService.swift
│   ├── PDFExporter.swift
│   └── BackupService.swift       # JSON export/import with base64 receipts
├── ViewModels/
│   ├── FinancingViewModel.swift
│   └── InstallmentViewModel.swift
├── Views/
│   ├── FinancingListView.swift
│   ├── DashboardView.swift
│   ├── InstallmentListView.swift
│   ├── InstallmentDetailView.swift
│   ├── AddFinancingView.swift
│   ├── ReportView.swift
│   ├── SimulationView.swift
│   └── SettingsView.swift
├── Helpers/
│   └── CurrencyFormatter.swift
├── en.lproj/Localizable.strings
└── pt-BR.lproj/Localizable.strings
```

## Adding a new schema version

1. Create `Database/SchemaV2.swift` with the updated models
2. In `MigrationPlan.swift`, add `SchemaV2.self` to `schemas` and a `.lightweight(...)` or `.custom(...)` stage
3. Update `CarLoanApp.swift` to use `SchemaV2.models`

Existing user data is preserved automatically for lightweight migrations (new fields with defaults).

## Contribution policy

- `main` is intended to stay protected.
- Direct changes should go through a branch and pull request.
- The repository owner (`@reisrb`) is the code owner for the repository.
- Configure GitHub branch protection/rulesets for `main` to require:
  - a pull request before merge;
  - the `build-and-test` check from the `iOS CI` workflow to pass;
  - code owner review when needed;
  - restricted direct pushes to the repository owner only.
