# Bugle Weather v1 requirements

## Product

- Product name: **Bugle Weather**.
- Free.
- iPhone-first.
- One weather grade shown to the user.
- Grade scale: **A+, A, A−, B+, B, B−, C+, C, C−, D+, D, D−, F**.
- No F+/F−.
- Default preference settings reproduce the canonical Bugle rubric.
- Personalization modifies that same grade; do not display a second canonical grade.

## Personalization

Five human-language, five-position controls:

1. Temperature: Cooler ↔ Warmer
2. Humidity: Crisp ↔ Muggy is fine
3. Rain: Hate it ↔ Don't mind it
4. Sun: Clouds are fine ↔ Give me sun
5. Wind: Still ↔ Breezy is fine

No weight percentages or raw algorithm controls in the primary UI.

## Weather data

- Open-Meteo global forecast API.
- `timezone=auto`.
- Fahrenheit/mph/inches internally for v1 grading; display-unit localization can be added later without changing the grading engine.
- Grade the usable day from 8 AM to 8 PM local time, while daily high/low and hazards can influence the result.
- U.S.: query active NWS alerts for the point.
- Outside U.S.: no alert-system integration required in v1.

## Determinism

Same weather input + same preference settings must always produce the same grade and explanation.

## Explainability

Every factor must return:

- factor name
- factor grade
- human-readable reason

Overall grade is the worst meaningful factor. Minor flaws do not add together as points.

## Safety / alert invariants

- Rain alone never creates F.
- Alert effects are based on overlap with the 8 AM–8 PM local usable-day window.
- NWS Watch is informational only; actual forecast conditions determine the grade.
- NWS Advisory caps the day at D only with at least 2 hours of usable-day overlap.
- NWS Warning makes the day F when it overlaps the usable day; an entirely overnight warning is informational for the daytime grade.
- NWS Statement / other products are informational only.
- If warning/advisory timing is unavailable, use the conservative original Bugle fallback.
- Heat index 105°F+ makes the day F.
- User preferences cannot weaken safety-alert rules.

## Widget

- Home Screen `systemSmall` widget in v1.
- Shows location, large grade, verdict, high/low, and short deterministic explanation.
- Uses same `BugleCore` grading package as main app.
- Refresh request roughly every two hours; WidgetKit controls actual scheduling.
- Cache last successful grade for offline/error fallback.
