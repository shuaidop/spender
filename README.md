# Spender

A macOS app for importing credit card statements, classifying transactions with AI, and analyzing spending patterns.

## Download & Install

1. Download **[Spender.dmg](https://github.com/shuaidop/spender/releases/latest/download/Spender.dmg)** from the latest release
2. Open the DMG file
3. Drag **Spender** to your **Applications** folder
4. On first launch: right-click the app → **Open** → click **Open** (required once for unsigned apps)
5. Go to **Settings → API Key** and enter your [OpenAI API key](https://platform.openai.com/api-keys) to enable AI features
6. Start importing credit card statements from the **Import** tab

> **Requirements:** macOS 14.0 (Sonoma) or later. AI features require an OpenAI API key. The app works without one, but auto-categorization and AI chat/analysis will be disabled.

## Features

- **PDF Statement Import** — Parse Chase and Amex credit card PDF statements automatically
- **AI-Powered Classification** — Categorize transactions using OpenAI with 37 spending categories
- **Smart Deduplication** — Detect and skip duplicate imports; find and remove refund pairs
- **Interactive Dashboard** — Annual overview with donut charts, monthly trends, top merchants, and credits
- **Monthly Analysis** — Per-month breakdowns with category drill-down, stat cards, and credits tracking
- **Optimization Tips** — Auto-generated spending tips based on your data (dining, subscriptions, fees, etc.)
- **Report Generation** — Monthly and annual markdown reports with optional AI analysis
- **AI Chat** — Ask questions about your spending data in natural language
- **Multi-Card Support** — Track multiple credit cards with custom colors and names
- **Category Management** — Edit, merge, and customize spending categories

## Tech Stack

- **SwiftUI** — Native macOS interface
- **SwiftData** — Persistent storage for transactions, cards, and categories
- **Swift Charts** — Interactive donut charts, bar charts, and trend lines
- **OpenAI Swift SDK** — Transaction classification and AI chat/analysis
- **CoreXLSX** — Excel statement parsing support

---

## Development

### Requirements

- macOS 14.0+
- Xcode 16.0+
- Swift 6.0

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/shuaidop/spender.git
   cd spender
   ```

2. Open the project:
   ```bash
   open Spender.xcodeproj
   ```
   Or generate from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   xcodegen generate
   ```

3. Build and run (Cmd+R in Xcode). Swift packages resolve automatically.

### Project Structure

```
Spender/
├── Analysis/          # AnalysisEngine, report generation, optimization tips
├── Chat/              # AI chat view model
├── Classification/    # AI-powered transaction classification engine
├── Models/            # SwiftData models (Transaction, Card, SpendingCategory, etc.)
├── Parsing/           # PDF statement parsers (Chase, Amex)
├── Resources/         # Assets, app icon
├── Utilities/         # Currency formatting, date formatters, extensions
└── Views/
    ├── Analysis/      # Spending analysis tabs (monthly, categories, trends, tips)
    ├── Chat/          # AI chat interface
    ├── Components/    # Shared UI components (MarkdownView, etc.)
    ├── Dashboard/     # Annual overview dashboard
    ├── DevTools/      # Developer tools
    ├── Import/        # Statement import and review flow
    ├── Settings/      # API key, card management, category management
    ├── Sidebar/       # Navigation sidebar
    └── Transactions/  # Transaction list, detail, and filters
```

### Running Tests

```bash
xcodebuild test -scheme Spender -destination 'platform=macOS'
```

### Building for Distribution

```bash
xcodebuild archive -scheme Spender -destination 'platform=macOS' -archivePath /tmp/Spender.xcarchive
cp -R /tmp/Spender.xcarchive/Products/Applications/Spender.app build/
hdiutil create -volname Spender -srcfolder build/Spender.app -ov -format UDZO build/Spender.dmg
```

## License

Personal project. All rights reserved.
