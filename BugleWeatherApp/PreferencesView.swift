import SwiftUI
import BugleCore

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WeatherPreferences
    let onSave: (WeatherPreferences) -> Void

    init(preferences: WeatherPreferences, onSave: @escaping (WeatherPreferences) -> Void) {
        _draft = State(initialValue: preferences)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PreferenceSlider(
                        title: "Temperature",
                        left: "Cooler",
                        right: "Warmer",
                        value: binding(\.temperatureBias)
                    )
                    PreferenceSlider(
                        title: "Humidity",
                        left: "Crisp",
                        right: "Muggy is fine",
                        value: binding(\.humidityTolerance)
                    )
                    PreferenceSlider(
                        title: "Rain",
                        left: "Hate it",
                        right: "Don't mind it",
                        value: binding(\.rainTolerance)
                    )
                    PreferenceSlider(
                        title: "Sun",
                        left: "Clouds are fine",
                        right: "Give me sun",
                        value: binding(\.sunPreference)
                    )
                    PreferenceSlider(
                        title: "Wind",
                        left: "Still",
                        right: "Breezy is fine",
                        value: binding(\.windTolerance)
                    )
                } header: {
                    Text("Your weather taste")
                } footer: {
                    Text("These move Bugle Weather's comfort thresholds. Safety alerts are never personalized.")
                }

                Section {
                    Button("Reset to Berno Bugle defaults") {
                        draft = .canonical
                    }
                }

                Section {
                    Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    Text("In the U.S., active National Weather Service alerts are included in the grade. Elsewhere, v1 uses Open-Meteo weather data without a local alert system.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Preferences")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<WeatherPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = min(2, max(-2, $0)) }
        )
    }
}

private struct PreferenceSlider: View {
    let title: String
    let left: String
    let right: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(levelText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: -2...2,
                step: 1
            )
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var levelText: String {
        switch value {
        case -2: left
        case -1: "Leans " + left.lowercased()
        case 1: "Leans " + right.lowercased()
        case 2: right
        default: "Bugle default"
        }
    }
}
