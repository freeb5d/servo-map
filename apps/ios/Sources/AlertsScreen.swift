import SwiftUI

/** Alert kinds and when they may arrive. Sending starts with decision 0004's phase 4. */
struct AlertsScreen: View {
    @AppStorage("alertCycleLow") private var cycleLow = false
    @AppStorage("quietStart") private var quietStart = 22
    @AppStorage("quietEnd") private var quietEnd = 7

    var body: some View {
        List {
            PriceAlertsSection()
            Section {
                Toggle("Prices near home are low", isOn: $cycleLow).paperRow()
            } footer: {
                Text("When the average near home reaches the bottom of its 60-day range.")
            }
            Section {
                Group {
                    Picker("Quiet from", selection: $quietStart) { ForEach(18..<24, id: \.self) { Text(hour($0)).tag($0) } }
                    Picker("Until", selection: $quietEnd) { ForEach(5..<11, id: \.self) { Text(hour($0)).tag($0) } }
                }
                .paperRow()
            } header: {
                Text("Quiet hours")
            } footer: {
                Text("At most one alert a day, never in quiet hours.")
            }
        }
        .paperList()
    }

    private func hour(_ h: Int) -> String {
        Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)?.formatted(date: .omitted, time: .shortened) ?? "\(h):00"
    }
}
