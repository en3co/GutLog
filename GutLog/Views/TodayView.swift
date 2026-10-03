import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @Query(sort: \Symptom.timestamp, order: .reverse) private var symptoms: [Symptom]
    @Query(sort: \Stool.timestamp, order: .reverse) private var stools: [Stool]

    @State private var day: Date = .now
    @State private var sheet: AddSheet?
    @State private var selectedItem: TimelineItem?
    @State private var undo: UndoBanner?

    private var calendar: Calendar { .current }

    private var items: [TimelineItem] {
        let m = meals.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.meal)
        let s = symptoms.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.symptom)
        let t = stools.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.map(TimelineItem.stool)
        return (m + s + t).sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            TimelineRow(item: item)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                addBar
                    .background(.bar)
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.large)
            .modifier(DaySubtitle(text: daySubtitle))
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
                    .disabled(calendar.isDateInToday(day) || day > Date())
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                EntryDetailView(item: item)
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .meal:
                    AddMealView(day: day)
                case .symptom:
                    AddSymptomView(day: day)
                case .stool:
                    AddStoolView(day: day)
                }
            }
            .overlay(alignment: .bottom) {
                if let undo {
                    UndoToast(message: undo.message) {
                        undo.restore()
                        self.undo = nil
                    }
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: undo != nil)
        }
    }

    private var dayTitle: String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        f.timeZone = calendar.timeZone
        return f.string(from: day)
    }

    private var daySubtitle: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.timeZone = calendar.timeZone
        return f.string(from: day)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing logged yet", systemImage: "fork.knife")
        } description: {
            Text("Log the next meal, a symptom, or a stool. One tap from the buttons below.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addBar: some View {
        HStack(spacing: 8) {
            addButton("Meal", systemImage: "fork.knife", sheet: .meal)
            addButton("Symptom", systemImage: "exclamationmark.circle", sheet: .symptom)
            addButton("Stool", systemImage: "drop", sheet: .stool)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func addButton(_ title: String, systemImage: String, sheet: AddSheet) -> some View {
        let button = Button {
            self.sheet = sheet
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        return Group {
            if #available(iOS 26, *) {
                button.buttonStyle(.glass)
            } else {
                button.buttonStyle(.bordered)
            }
        }
    }

    private func delete(_ item: TimelineItem) {
        switch item {
        case .meal(let meal):
            let hk = [
                meal.hkEnergyUUID,
                meal.hkProteinUUID,
                meal.hkCarbsUUID,
                meal.hkFatUUID,
                meal.hkFibreUUID,
                meal.hkWaterUUID
            ].compactMap { $0 }
            let snapshot = MealSnapshot(meal)
            context.delete(meal)
            try? context.save()
            Task { await HealthKitWriter.shared.deleteQuantityUUIDs(hk) }
            presentUndo("Meal deleted") {
                snapshot.insert(into: context)
            }
        case .symptom(let symptom):
            let hk = symptom.hkSampleUUID
            let snapshot = SymptomSnapshot(symptom)
            context.delete(symptom)
            try? context.save()
            Task { await HealthKitWriter.shared.deleteQuantityUUIDs([hk].compactMap { $0 }) }
            presentUndo("Symptom deleted") {
                snapshot.insert(into: context)
            }
        case .stool(let stool):
            let snapshot = StoolSnapshot(stool)
            context.delete(stool)
            try? context.save()
            presentUndo("Stool deleted") {
                snapshot.insert(into: context)
            }
        }
    }

    private func presentUndo(_ message: String, restore: @escaping () -> Void) {
        undo = UndoBanner(message: message, restore: restore)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if undo?.message == message {
                undo = nil
            }
        }
    }
}

private struct UndoBanner {
    let message: String
    let restore: () -> Void
}

private struct UndoToast: View {
    let message: String
    let undo: () -> Void

    var body: some View {
        HStack {
            Text(message)
            Spacer()
            Button("Undo", action: undo)
                .bold()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct DaySubtitle: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle(text)
        } else {
            content
        }
    }
}

enum AddSheet: String, Identifiable {
    case meal, symptom, stool
    var id: String { rawValue }
}

private struct MealSnapshot {
    let timestamp: Date
    let name: String
    let notes: String
    let portionNote: String
    let kcal: Double?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let fibreG: Double?
    let waterML: Double?
    let isRepeat: Bool

    init(_ m: Meal) {
        timestamp = m.timestamp
        name = m.name
        notes = m.notes
        portionNote = m.portionNote
        kcal = m.kcal
        proteinG = m.proteinG
        carbsG = m.carbsG
        fatG = m.fatG
        fibreG = m.fibreG
        waterML = m.waterML
        isRepeat = m.isRepeat
    }

    func insert(into context: ModelContext) {
        let meal = Meal(
            timestamp: timestamp,
            name: name,
            notes: notes,
            portionNote: portionNote,
            kcal: kcal,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fibreG: fibreG,
            waterML: waterML,
            isRepeat: isRepeat
        )
        context.insert(meal)
        try? context.save()
        Task { @MainActor in
            await HealthKitWriter.shared.syncMeal(meal)
        }
    }
}

private struct SymptomSnapshot {
    let timestamp: Date
    let kind: SymptomKind
    let severity: Int
    let notes: String

    init(_ s: Symptom) {
        timestamp = s.timestamp
        kind = s.kind
        severity = s.severity
        notes = s.notes
    }

    func insert(into context: ModelContext) {
        let s = Symptom(timestamp: timestamp, kind: kind, severity: severity, notes: notes)
        context.insert(s)
        try? context.save()
        Task { @MainActor in
            await HealthKitWriter.shared.syncSymptom(s)
        }
    }
}

private struct StoolSnapshot {
    let timestamp: Date
    let bristol: Int
    let notes: String

    init(_ s: Stool) {
        timestamp = s.timestamp
        bristol = s.bristol
        notes = s.notes
    }

    func insert(into context: ModelContext) {
        let s = Stool(timestamp: timestamp, bristol: bristol, notes: notes)
        context.insert(s)
        try? context.save()
    }
}

struct TimelineRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.timeZone = .current
        return f.string(from: item.timestamp)
    }

    private var title: String {
        switch item {
        case .meal(let m): return m.name.isEmpty ? "Meal" : m.name
        case .symptom(let s): return s.kind.title
        case .stool(let s): return "Bristol \(s.bristol)"
        }
    }

    private var subtitle: String? {
        switch item {
        case .meal(let m):
            var bits: [String] = []
            if m.isRepeat { bits.append("Repeat") }
            if !m.portionNote.isEmpty { bits.append(m.portionNote) }
            if let k = m.kcal { bits.append("\(Int(k)) kcal") }
            if !m.notes.isEmpty { bits.append(m.notes) }
            return bits.joined(separator: " · ")
        case .symptom(let s):
            var bits = ["Severity \(s.severity)/10"]
            if !s.notes.isEmpty { bits.append(s.notes) }
            return bits.joined(separator: " · ")
        case .stool(let s):
            var bits = [s.bristolType.shortLabel]
            if !s.notes.isEmpty { bits.append(s.notes) }
            return bits.joined(separator: " · ")
        }
    }

    private var icon: String {
        switch item {
        case .meal: return "fork.knife"
        case .symptom: return "exclamationmark.circle"
        case .stool: return "drop"
        }
    }
}

extension TimelineItem: Hashable {
    static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
