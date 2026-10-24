import Foundation

enum CSVExporter {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func csv(meals: [Meal], symptoms: [Symptom], stools: [Stool]) -> String {
        var rows: [String] = []
        rows.append([
            "kind",
            "id",
            "timestamp",
            "name",
            "notes",
            "portion_note",
            "kcal",
            "protein_g",
            "carbs_g",
            "fat_g",
            "fibre_g",
            "water_ml",
            "is_repeat",
            "symptom_type",
            "severity",
            "bristol",
            "bristol_label"
        ].joined(separator: ","))

        for meal in meals.sorted(by: { $0.timestamp < $1.timestamp }) {
            rows.append(csvRow([
                "meal",
                meal.id.uuidString,
                iso.string(from: meal.timestamp),
                meal.name,
                meal.notes,
                meal.portionNote,
                num(meal.kcal),
                num(meal.proteinG),
                num(meal.carbsG),
                num(meal.fatG),
                num(meal.fibreG),
                num(meal.waterML),
                meal.isRepeat ? "true" : "false",
                "",
                "",
                "",
                ""
            ]))
        }
        for s in symptoms.sorted(by: { $0.timestamp < $1.timestamp }) {
            rows.append(csvRow([
                "symptom",
                s.id.uuidString,
                iso.string(from: s.timestamp),
                "",
                s.notes,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                s.kind.title,
                String(s.severity),
                "",
                ""
            ]))
        }
        for s in stools.sorted(by: { $0.timestamp < $1.timestamp }) {
            rows.append(csvRow([
                "stool",
                s.id.uuidString,
                iso.string(from: s.timestamp),
                "",
                s.notes,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                String(s.bristol),
                s.bristolType.shortLabel
            ]))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func daySummary(
        date: Date,
        meals: [Meal],
        symptoms: [Symptom],
        stools: [Stool],
        calendar: Calendar = .current
    ) -> String {
        let day = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = calendar.timeZone

        let time = DateFormatter()
        time.dateStyle = .none
        time.timeStyle = .short
        time.timeZone = calendar.timeZone

        var lines: [String] = []
        lines.append("Gut Log — \(formatter.string(from: day))")
        lines.append("")

        let dayMeals = meals.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp < $1.timestamp }
        let daySymptoms = symptoms.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp < $1.timestamp }
        let dayStools = stools.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp < $1.timestamp }

        if dayMeals.isEmpty && daySymptoms.isEmpty && dayStools.isEmpty {
            lines.append("No entries.")
            return lines.joined(separator: "\n")
        }

        lines.append("Meals (\(dayMeals.count))")
        for m in dayMeals {
            var extra: [String] = []
            if !m.portionNote.isEmpty { extra.append(m.portionNote) }
            if let k = m.kcal { extra.append("\(Int(k)) kcal") }
            let suffix = extra.isEmpty ? "" : " — " + extra.joined(separator: ", ")
            lines.append("  \(time.string(from: m.timestamp))  \(m.name)\(suffix)")
            if !m.notes.isEmpty { lines.append("    \(m.notes)") }
        }
        lines.append("")
        lines.append("Symptoms (\(daySymptoms.count))")
        for s in daySymptoms {
            lines.append("  \(time.string(from: s.timestamp))  \(s.kind.title)  severity \(s.severity)/10")
            if !s.notes.isEmpty { lines.append("    \(s.notes)") }
        }
        lines.append("")
        lines.append("Stools (\(dayStools.count))")
        for s in dayStools {
            lines.append("  \(time.string(from: s.timestamp))  Bristol \(s.bristol) (\(s.bristolType.shortLabel))")
            if !s.notes.isEmpty { lines.append("    \(s.notes)") }
        }
        return lines.joined(separator: "\n")
    }

    private static func num(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ field: String) -> String {
        var value = field
        let trimmed = value.drop(while: { $0 == " " || $0 == "\t" })
        if let first = trimmed.first, "=+-@".contains(first) {
            value = "'" + value
        }
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value != field {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
