import SwiftUI

/** This month on You: spent, under the local average and fill-ups as a ruled row, then the month's fill-ups. */
struct YouMonthSection: View {
    @Environment(FillUpLog.self) private var log
    @State private var adding = false

    var body: some View {
        let now = Date.now
        let month = MonthSummary.of(log.entries, month: now)
        let fills = log.entries.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: now.formatted(.dateTime.month(.wide))) {
                NavigationLink("Log", value: YouScreen.Page.log)
            }
            RuledFigures(figures: [
                RuledFigure(label: "Spent", value: money(month.spent)),
                RuledFigure(label: "Under average", value: money(month.saved),
                            color: month.saved > 0 ? ServoMapColor.priceCheap : ServoMapColor.ink),
                RuledFigure(label: "Fill-ups", value: "\(month.count)"),
            ])
            // RuledFigures (Trends/TrendsParts.swift) insets itself for a full-width page; this section already is.
            .padding(.horizontal, -20)
            .padding(.top, 8)
            ForEach(fills) { MonthFillRow(fillUp: $0) }
            if fills.isEmpty {
                Text("No fill-ups logged this month.")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    .padding(.top, 10)
            }
            Button { adding = true } label: {
                Label("Log a fill-up", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .actionFont()
            .padding(.top, 14)
        }
        .sheet(isPresented: $adding) { AddFillUpSheet(station: nil) }
    }
}

/** A fill-up as a ledger row: its date, the station with litres and price, and what it cost. */
private struct MonthFillRow: View {
    let fillUp: FillUp

    var body: some View {
        HStack(spacing: 12) {
            Text(fillUp.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(ServoMapFont.body(.footnote)).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
                .lineLimit(1).fixedSize()
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(fillUp.stationName).font(ServoMapFont.body(.callout)).lineLimit(1)
                Text("\(fillUp.litres.formatted(.number.precision(.fractionLength(1)))) L at \(fillUp.centsPerLitre.formatted(.number.precision(.fractionLength(1))))¢")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            Spacer(minLength: 8)
            Text(money(fillUp.cost)).font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}
