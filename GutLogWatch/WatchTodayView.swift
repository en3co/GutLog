import SwiftUI
import SwiftData

private enum WatchRoute: Hashable {
    case symptom
    case symptomSeverity(SymptomKind)
    case stool
    case meal
}

struct WatchTodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meal.timestamp) private var meals: [Meal]
    @Query(sort: \Symptom.timestamp) private var symptoms: [Symptom]
    @Query(sort: \Stool.timestamp) private var stools: [Stool]

    @State private var day = Date.now
    @State private var path = NavigationPath()

    private var calendar: Calendar { .current }

    /// Same sRGB green as GutLog/Assets.xcassets/AccentColor.
    private static let accent = Color(red: 0.220, green: 0.520, blue: 0.420)

    private var items: [TimelineItem] {
        let mealsToday = meals.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.meal)
        let symptomsToday = symptoms.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.symptom)
        let stoolsToday = stools.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.stool)
        return (mealsToday + symptomsToday + stoolsToday).sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: WatchRoute.meal) {
                        Label("Meal", systemImage: "fork.knife")
                    }
                    NavigationLink(value: WatchRoute.symptom) {
                        Label("Symptom", systemImage: "exclamationmark.circle")
                    }
                    NavigationLink(value: WatchRoute.stool) {
                        Label("Stool", systemImage: "drop")
                    }
                }

                Section(dayTitle) {
                    if items.isEmpty {
                        Text("Nothing logged")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            WatchTimelineRow(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle(Text("Gut Log").foregroundStyle(Self.accent))
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .symptom:
                    WatchAddSymptomView { kind in
                        path.append(WatchRoute.symptomSeverity(kind))
                    }
                case .symptomSeverity(let kind):
                    WatchSymptomSeverityView(kind: kind) {
                        path = NavigationPath()
                    }
                case .stool:
                    WatchAddStoolView {
                        path = NavigationPath()
                    }
                case .meal:
                    WatchAddMealView {
                        path = NavigationPath()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous day")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next day")
                    .disabled(calendar.isDateInToday(day) || day > .now)
                }
            }
        }
    }

    private var dayTitle: String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func delete(_ item: TimelineItem) {
        switch item {
        case .meal(let meal): context.delete(meal)
        case .symptom(let symptom): context.delete(symptom)
        case .stool(let stool): context.delete(stool)
        }
        try? context.save()
        WatchSync.shared.send(.delete(item.id))
    }
}

private struct WatchTimelineRow: View {
    let item: TimelineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .lineLimit(2)
            Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch item {
        case .meal(let meal):
            return meal.name
        case .symptom(let symptom):
            return "\(symptom.kind.title) · \(symptom.severity)"
        case .stool(let stool):
            return "Type \(stool.bristol) · \(stool.bristolType.shortLabel)"
        }
    }
}
