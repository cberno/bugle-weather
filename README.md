# Bugle Weather — v0.1 starter

A tiny iPhone weather app whose main output is one deterministic, personalized grade for the day: **A+ through F**.

## What is implemented

- Native SwiftUI iPhone app.
- Small WidgetKit Home Screen widget (`systemSmall`).
- Global Open-Meteo forecast data with the location's local timezone.
- U.S.-only active NWS alert overlay. Outside the U.S., weather grading still works globally; v1 simply has no local alert-system integration.
- One personalized grade. Default preferences exactly represent the Berno Bugle baseline.
- Five simple preference controls: temperature, humidity, rain, sun, wind.
- Winter rules: wind chill, snow, freezing rain, raw cold.
- Summer rules: heat index, humidity/dew point, storms.
- Explainable factor-by-factor grading.
- Shared App Group storage so app preferences/location and widget stay in sync.
- 15 deterministic unit tests for the grading engine.

## Grading philosophy

The engine is a rubric, **not a weighted average**. Each factor receives a grade. The overall day inherits the worst meaningful factor, so two minor flaws don't compound into an artificially bad day. A+ is reserved for genuinely exceptional weather.

The canonical source rubric is:

- **A** — high 55–85°F, dry, sun, calm, no alerts. Rare; cancel-plans weather.
- **B** — good with one flaw: warm to 92°F, a brief shower window, or gray but dry; most of the day usable.
- **C** — usable with effort: 92–97°F or sticky-humid, on-and-off rain, or raw cold.
- **D** — hostile most of the day: heat index 100–104°F, rain most hours, or an NWS advisory.
- **F** — dangerous/day-killing: NWS warning, heat index 105°F+, or truly severe conditions.

The implementation adds +/- bands between those anchors, with F left unmodified.

## Open in Xcode

This folder includes an `XcodeGen` project spec so the project is reproducible and not dependent on a hand-edited `.pbxproj`.

1. On a Mac with Xcode installed, install XcodeGen if needed:
   `brew install xcodegen`
2. In Terminal, `cd` into this folder and run:
   `xcodegen generate`
3. Open `BugleWeather.xcodeproj`.
4. Select your Apple Developer team under **Signing & Capabilities** for both targets.
5. If the bundle ID is unavailable, change `com.charleyberno.BugleWeather` and the widget bundle ID in `project.yml`.
6. Make sure both targets have the same App Group. The starter uses:
   `group.com.charleyberno.BugleWeather`
7. Run the app on your iPhone, allow location access, and refresh once.
8. Long-press the Home Screen → **Edit** → **Add Widget** → **Bugle Weather**.

The widget intentionally uses the last location recorded by the app. This keeps v0.1 reliable and battery-light. A later version can request widget-specific location updates if we decide it matters.

## Test the grading engine

From `BugleCore/`:

```bash
swift test
```

## Data / attribution

Weather data: Open-Meteo. The app includes an attribution link in Preferences.

NWS alerts: `api.weather.gov/alerts/active?point=lat,lon` for U.S. coordinates.

## Next engineering passes

1. Backtest the rubric against historical/historical-forecast weather to tune grade distribution.
2. Add location search / pinned locations.
3. Improve deterministic editorial strings by combining the two most important factors.
4. Add a medium widget only if it earns its keep.
5. App Store icon, screenshots, privacy text, and release signing.
