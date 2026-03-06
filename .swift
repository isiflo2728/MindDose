//
//  SwiftUIView.swift
//  MedTracker
//
//  Created by Isidoro Flores on 2/27/26.
//

struct SummaryReportView: some View {
    @ObservedObject var journalStore: JournalStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var timeRange: TimeRange = .twoWeeks
    
    enum TimeRange: String, CaseIterable {
        case oneWeek = "1 Week"
        case twoWeeks = "2 Weeks"
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case oneYear = "1 Year"
        
        var days: Int {
            switch self {
            case .oneWeek: return 7
            case .twoWeeks: return 14
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .oneYear: return 365
            }
        }
    }
    
    private var rangeEntries: [JournalEntry] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: .now)
        guard let start = cal.date(byAdding: .day, value: -timeRange.days, to: end) else { return [] }
        return journalStore.entries(inRange: start, end: end)
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Time range picker
                    Picker("Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if rangeEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No entries in this period")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        overviewCard(color: color)
                        moodDistribution(color: color)
                        perMedicationBreakdown(color: color)
                        sideEffectsOverview(color: color)
                        sleepAndEnergy(color: color)
                        keyExcerpts(color: color)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [color.opacity(0.08), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Overview
    
    private func overviewCard(color: Color) -> some View {
        let entries = rangeEntries
        let avgMood = Double(entries.map(\.mood.numericValue).reduce(0, +)) / Double(entries.count)
        let avgEnergy = Double(entries.map(\.energyLevel).reduce(0, +)) / Double(entries.count)
        let sleepEntries = entries.compactMap(\.sleepQuality)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(color)
                Text("Overview")
                    .font(.headline)
            }
            
            Divider()
            
            summaryRow(label: "Total Entries", value: "\(entries.count)")
            summaryRow(label: "Period", value: "\(timeRange.rawValue)")
            summaryRow(label: "Avg Mood", value: String(format: "%.1f/5", avgMood))
            summaryRow(label: "Avg Energy", value: String(format: "%.1f/5", avgEnergy))
            
            if !sleepEntries.isEmpty {
                let sleepCounts = Dictionary(grouping: sleepEntries, by: { $0 })
                if let mostCommon = sleepCounts.max(by: { $0.value.count < $1.value.count }) {
                    summaryRow(label: "Typical Sleep", value: mostCommon.key.rawValue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
    
    // MARK: - Mood Distribution
    
    private func moodDistribution(color: Color) -> some View {
        let entries = rangeEntries
        let total = Double(entries.count)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "face.smiling.inverse")
                    .foregroundStyle(color)
                Text("Mood Distribution")
                    .font(.headline)
            }
            
            ForEach(JournalEntry.Mood.allCases, id: \.self) { m in
                let count = entries.filter { $0.mood == m }.count
                let pct = total > 0 ? Double(count) / total : 0
                
                HStack(spacing: 10) {
                    Text(m.emoji)
                        .frame(width: 28)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(m.color.opacity(0.6))
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 20)
                    
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Per-Medication Breakdown
    
    private func perMedicationBreakdown(color: Color) -> some View {
        let entries = rangeEntries
        let medsWithEntries = medStore.medications.filter { med in
            entries.contains { $0.medicationIDs.contains(med.id) }
        }
        
        return Group {
            if !medsWithEntries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(color)
                        Text("By Medication")
                            .font(.headline)
                    }
                    
                    ForEach(medsWithEntries) { med in
                        let medEntries = entries.filter { $0.medicationIDs.contains(med.id) }
                        let avgMood = Double(medEntries.map(\.mood.numericValue).reduce(0, +)) / Double(medEntries.count)
                        let effects = medEntries.flatMap(\.sideEffects)
                        let uniqueEffects = Array(Set(effects))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(med.color.color)
                                    .frame(width: 10, height: 10)
                                Text(med.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(med.dosage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "Avg Mood: %.1f", avgMood))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(avgMood >= 3.5 ? .green : avgMood >= 2.5 ? .orange : .red)
                            }
                            
                            HStack {
                                Text("\(medEntries.count) entries")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                if !uniqueEffects.isEmpty {
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text("Side effects: \(uniqueEffects.joined(separator: ", "))")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .lineLimit(1)
                                }
                            }
                            
                            if med != medsWithEntries.last {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: color.opacity(0.1), radius: 10, y: 5)
                )
            }
        }
    }
    
    // MARK: - Side Effects
    
    private func sideEffectsOverview(color: Color) -> some View {
        let allEffects = rangeEntries.flatMap(\.sideEffects)
        let grouped = Dictionary(grouping: allEffects, by: { $0.lowercased() })
            .sorted { $0.value.count > $1.value.count }
        
        return Group {
            if !grouped.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Reported Side Effects")
                            .font(.headline)
                    }
                    
                    ForEach(grouped.prefix(8), id: \.key) { effect, occurrences in
                        HStack {
                            Text(effect.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text("\(occurrences.count)x")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: color.opacity(0.1), radius: 10, y: 5)
                )
            }
        }
    }
    
    // MARK: - Sleep & Energy
    
    private func sleepAndEnergy(color: Color) -> some View {
        let entries = rangeEntries
        let avgEnergy = Double(entries.map(\.energyLevel).reduce(0, +)) / Double(entries.count)
        let sleepEntries = entries.compactMap(\.sleepQuality)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(color)
                Text("Sleep & Energy")
                    .font(.headline)
            }
            
            if !sleepEntries.isEmpty {
                HStack(spacing: 16) {
                    ForEach(JournalEntry.SleepQuality.allCases, id: \.self) { sq in
                        let count = sleepEntries.filter { $0 == sq }.count
                        if count > 0 {
                            VStack(spacing: 4) {
                                Image(systemName: sq.icon)
                                    .font(.body)
                                Text("\(count)")
                                    .font(.caption.weight(.bold))
                                Text(sq.rawValue)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.body)
                            .foregroundStyle(color)
                        Text(String(format: "%.1f", avgEnergy))
                            .font(.caption.weight(.bold))
                        Text("Avg Energy")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Key Excerpts
    
    private func keyExcerpts(color: Color) -> some View {
        let notable = rangeEntries.filter {
            $0.mood == .veryBad || $0.mood == .veryGood || !$0.sideEffects.isEmpty
        }
        .prefix(5)
        
        return Group {
            if !notable.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundStyle(color)
                        Text("Notable Entries")
                            .font(.headline)
                    }
                    
                    Text("Entries with extreme moods or side effects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(notable)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.mood.emoji)
                                Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.caption.weight(.semibold))
                                if !entry.title.isEmpty {
                                    Text("— \(entry.title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Text(entry.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(entry.mood.color.opacity(0.06))
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: color.opacity(0.1), radius: 10, y: 5)
                )
            }
        }
    }
}

// MARK: - FlowLayout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
