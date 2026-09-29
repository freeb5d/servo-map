import SwiftUI

/**
 * The fill-up log in the Health manner: this month at the top, then cards for spending over the
 * last six months, the price paid against the local average, and habits; then every fill-up by month.
 */
struct LogScreen: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @State private var adding = false
    @AppStorage("carName") private var carName = "My car"
    @AppStorage("tankLitres") private var tankLitres = 50

    var body: some View {
        NavigationStack {
            List {
                if log.entries.isEmpty {
                    emptySection
                } else {
                    monthSection
                    spendingSection
                    priceSection
                    habitsSection
                }
                Section("Your car") {
                    NavigationLink { CarForm() } label: {
                        LabeledContent(carName, value: "\(store.fuel.rawValue), \(tankLitres) L tank")
                    }
                    .paperRow()
                }
                ForEach(byMonth, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.fills) { FillUpRow(fillUp: $0).paperRow() }
                            .onDelete { offsets in log.remove(Set(offsets.map { group.fills[$0].id })) }
                    }
                }
            }
            .paperList()
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log a fill-up", systemImage: "plus") { adding = true }.buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $adding) { AddFillUpSheet(station: nil) }
        }
    }

    // MARK: Cards

    private var monthSection: some View {
        let now = MonthSummary.of(log.entries, month: .now)
        let before = Calendar.current.date(byAdding: .month, value: -1, to: .now).map { MonthSummary.of(log.entries, month: $0) }
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: Date.now.formatted(.dateTime.month(.wide)), symbol: "calendar", note: "\(now.count) fill-up\(now.count == 1 ? "" : "s")")
                VStack(alignment: .leading, spacing: 2) {
                    Text(now.spent.formatted(.currency(code: "AUD"))).font(ServoMapFont.priceXl).monospacedDigit()
                    if let before, before.spent > 0 {
                        Text(comparison(now.spent, before.spent)).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    }
                }
                HStack(alignment: .top, spacing: 0) {
                    figure("Litres", now.litres.formatted(.number.precision(.fractionLength(1))))
                    Divider()
                    figure("Average price", now.litres > 0 ? (now.spent * 100 / now.litres).formatted(.number.precision(.fractionLength(1))) : "–")
                    Divider()
                    figure("Saved", now.saved.formatted(.currency(code: "AUD")), tint: now.saved > 0 ? ServoMapColor.priceCheap : ServoMapColor.ink)
                }
            }
            .padding(.vertical, 6)
            .paperRow()
        } footer: {
            Text("Saved is measured against the average nearby when you logged each fill-up.")
        }
    }

    private var spendingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Spending", symbol: "creditcard", note: "Last 6 months")
                MonthlySpendChart(months: MonthSummary.recent(log.entries, months: 6, now: .now))
            }
            .padding(.vertical, 6)
            .paperRow()
        }
    }

    private var priceSection: some View {
        let recent = Array(log.entries.prefix(12))
        let under = LogHabits.of(recent)?.averageUnder
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Price paid", symbol: "fuelpump", note: "Last \(recent.count) fill-ups")
                if let under {
                    Text(under >= 0
                         ? "You paid \(fmt(under))¢ a litre under the local average."
                         : "You paid \(fmt(-under))¢ a litre over the local average.")
                        .font(ServoMapFont.display(.body, weight: 500))
                }
                PricePaidChart(fills: recent)
                PricePaidLegend()
            }
            .padding(.vertical, 6)
            .paperRow()
        }
    }

    @ViewBuilder private var habitsSection: some View {
        if let h = LogHabits.of(log.entries) {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(title: "Habits", symbol: "repeat", note: "All fill-ups")
                    Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 14) {
                        GridRow {
                            figure("Usual fill", "\(fmt(h.averageLitres)) L")
                            figure("Fill every", h.daysBetween.map { "\(Int($0.rounded())) days" } ?? "–")
                        }
                        GridRow {
                            figure("Average paid", "\(fmt(h.averagePrice))¢")
                            figure("Most often", h.favourite?.name ?? "–", note: h.favourite.map { "\($0.count) times" })
                        }
                    }
                }
                .padding(.vertical, 6)
                .paperRow()
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "fuelpump").font(.system(size: 34, weight: .light)).foregroundStyle(ServoMapColor.ink3)
                Text("No fill-ups yet").font(ServoMapFont.display(.title3, weight: 500))
                Text("Log a fill-up from a station’s page or with the button above. Each one records what you paid and how it compares with the average nearby.")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Helpers

    /** Fill-ups in sections by calendar month, newest first. */
    private var byMonth: [(title: String, fills: [FillUp])] {
        let groups = Dictionary(grouping: log.entries) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return groups.keys.sorted(by: >).map { key in
            (key.formatted(.dateTime.month(.wide).year()), groups[key] ?? [])
        }
    }

    private func comparison(_ now: Double, _ before: Double) -> String {
        let last = Calendar.current.date(byAdding: .month, value: -1, to: .now)?.formatted(.dateTime.month(.wide)) ?? "last month"
        let diff = now - before
        let amount = abs(diff).formatted(.currency(code: "AUD").precision(.fractionLength(0)))
        return diff >= 0 ? "\(amount) more than \(last) so far" : "\(amount) less than \(last) so far"
    }

    private func figure(_ title: String, _ value: String, note: String? = nil, tint: Color = ServoMapColor.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            Text(value).font(ServoMapFont.display(.title3)).foregroundStyle(tint).lineLimit(2).minimumScaleFactor(0.7)
            if let note { Text(note).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

private func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }

private struct FillUpRow: View {
    let fillUp: FillUp

    var body: some View {
        HStack(spacing: 12) {
            BrandSeal(family: BrandFamily.resolve(fillUp.brand))
            VStack(alignment: .leading, spacing: 2) {
                Text(fillUp.stationName).lineLimit(1)
                Text("\(fillUp.date.formatted(.dateTime.weekday(.abbreviated).day().month())), \(fillUp.litres.formatted(.number.precision(.fractionLength(1)))) L at \(fillUp.centsPerLitre.formatted(.number.precision(.fractionLength(1))))")
                    .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(fillUp.cost.formatted(.currency(code: "AUD"))).font(ServoMapFont.display(.body))
                if fillUp.saved > 0 {
                    Text("Saved \(fillUp.saved.formatted(.currency(code: "AUD")))").font(ServoMapFont.small).foregroundStyle(ServoMapColor.priceCheap)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
