import SwiftUI
import UIKit

// MARK: - Journal Models

struct JournalEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var mood: Mood
    var title: String
    var content: String
    var medicationIDs: [UUID]    // linked medications
    var sideEffects: [String]
    var sleepQuality: SleepQuality?
    var energyLevel: Int         // 1-5
    
    enum Mood: String, Codable, CaseIterable {
        case veryBad = "Very Bad"
        case bad = "Bad"
        case neutral = "Neutral"
        case good = "Good"
        case veryGood = "Very Good"
        
        var emoji: String {
            switch self {
            case .veryBad: return "😣"
            case .bad: return "😔"
            case .neutral: return "😐"
            case .good: return "🙂"
            case .veryGood: return "😊"
            }
        }
        
        var numericValue: Int {
            switch self {
            case .veryBad: return 1
            case .bad: return 2
            case .neutral: return 3
            case .good: return 4
            case .veryGood: return 5
            }
        }
        
        var color: Color {
            switch self {
            case .veryBad: return .red
            case .bad: return .orange
            case .neutral: return .yellow
            case .good: return .mint
            case .veryGood: return .green
            }
        }
    }
    
    enum SleepQuality: String, Codable, CaseIterable {
        case terrible = "Terrible"
        case poor = "Poor"
        case fair = "Fair"
        case good = "Good"
        case excellent = "Excellent"
        
        var icon: String {
            switch self {
            case .terrible: return "moon.zzz"
            case .poor: return "moon"
            case .fair: return "moon.haze"
            case .good: return "moon.stars"
            case .excellent: return "sparkles"
            }
        }
    }
}

// MARK: - Journal Store

@MainActor
class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    
    private let saveKey = "saved_journal_entries"
    
    init() {
        load()
    }
    
    func add(_ entry: JournalEntry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        save()
    }
    
    func update(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            save()
        }
    }
    
    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }
    
    func entries(for date: Date) -> [JournalEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return entries.filter { cal.startOfDay(for: $0.date) == start }
    }
    
    func entries(forMedication medID: UUID) -> [JournalEntry] {
        entries.filter { $0.medicationIDs.contains(medID) }
    }
    
    func entries(inRange start: Date, end: Date) -> [JournalEntry] {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        return entries.filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= s && d <= e
        }
    }
    
    // MARK: Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = decoded
    }
}

// MARK: - Journal Tab View

struct JournalView: View {
    @ObservedObject var journalStore: JournalStore
    @ObservedObject var medStore: MedicationStore
    
    @State private var showNewEntry = false
    @State private var showSummary = false
    @State private var editingEntry: JournalEntry? = nil
    @State private var filterMode: FilterMode = .all
    @State private var selectedMedFilter: UUID? = nil
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case byMed = "By Medication"
    }
    
    private var filteredEntries: [JournalEntry] {
        switch filterMode {
        case .all:
            return journalStore.entries
        case .byMed:
            guard let medID = selectedMedFilter else { return journalStore.entries }
            return journalStore.entries(forMedication: medID)
        }
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [color.opacity(0.15), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if journalStore.entries.isEmpty {
                    emptyState(color: color)
                } else {
                    List {
                        Section {
                            moodTimeline(color: color)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        
                        Section {
                            filterBar(color: color)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        
                        Section {
                            ForEach(filteredEntries) { entry in
                                journalCard(entry, color: color)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation { journalStore.delete(entry) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingEntry = entry
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 60)
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showNewEntry = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [color, color.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Circle()
                                )
                                .shadow(color: color.opacity(0.5), radius: 10, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSummary = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(color)
                    }
                    .disabled(journalStore.entries.isEmpty)
                }
            }
            .sheet(isPresented: $showNewEntry) {
                NewJournalEntryView(
                    journalStore: journalStore,
                    medStore: medStore
                )
            }
            .sheet(item: $editingEntry) { entry in
                NewJournalEntryView(
                    journalStore: journalStore,
                    medStore: medStore,
                    editing: entry
                )
            }
            .sheet(isPresented: $showSummary) {
                SummaryReportView(
                    journalStore: journalStore,
                    medStore: medStore
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyState(color: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 50))
                .foregroundStyle(color.opacity(0.4))
            
            Text("Your Journal")
                .font(.title3.weight(.bold))
            
            Text("Track how you feel each day, link entries to medications, and generate reports for your doctor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showNewEntry = true
            } label: {
                Text("Write First Entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
        }
    }
    
    // MARK: - Mood Timeline (last 7 days)
    
    private func moodTimeline(color: Color) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days: [Date] = (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Mood This Week")
                .font(.headline)
            
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let dayEntries = journalStore.entries(for: day)
                    let avgMood = averageMood(for: dayEntries)
                    let isToday = cal.isDateInToday(day)
                    
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? color : .secondary)
                        
                        if let mood = avgMood {
                            Text(mood.emoji)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle().fill(mood.color.opacity(0.15))
                                )
                        } else {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text("–")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
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
    
    private func averageMood(for entries: [JournalEntry]) -> JournalEntry.Mood? {
        guard !entries.isEmpty else { return nil }
        let avg = Double(entries.map(\.mood.numericValue).reduce(0, +)) / Double(entries.count)
        let rounded = Int(avg.rounded())
        return JournalEntry.Mood.allCases.first { $0.numericValue == rounded }
    }
    
    // MARK: - Filter Bar
    
    private func filterBar(color: Color) -> some View {
        VStack(spacing: 10) {
            Picker("Filter", selection: $filterMode) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            if filterMode == .byMed && !medStore.medications.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(medStore.medications) { med in
                            let isSelected = selectedMedFilter == med.id
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedMedFilter = isSelected ? nil : med.id
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(med.color.color)
                                        .frame(width: 8, height: 8)
                                    Text(med.name)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill)
                                    )
                                )
                                .overlay(
                                    Capsule().stroke(
                                        isSelected ? color : .clear, lineWidth: 1.5
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Journal Card
    
    private func journalCard(_ entry: JournalEntry, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: date + mood
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold))
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(entry.mood.emoji)
                        .font(.title3)
                    Text(entry.mood.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(entry.mood.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(entry.mood.color.opacity(0.12))
                )
            }
            
            // Title
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.headline)
            }
            
            // Content preview
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // Tags row
            HStack(spacing: 12) {
                // Linked medications
                if !entry.medicationIDs.isEmpty {
                    let meds = medStore.medications.filter { entry.medicationIDs.contains($0.id) }
                    HStack(spacing: 4) {
                        Image(systemName: "pills.fill")
                            .font(.caption2)
                            .foregroundStyle(color)
                        ForEach(meds) { med in
                            Text(med.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(med.color.color)
                        }
                    }
                }
                
                // Side effects
                if !entry.sideEffects.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(entry.sideEffects.count) side effect\(entry.sideEffects.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Spacer()
                
                // Sleep + energy
                if let sleep = entry.sleepQuality {
                    HStack(spacing: 2) {
                        Image(systemName: sleep.icon)
                            .font(.caption2)
                        Text(sleep.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("\(entry.energyLevel)/5")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.08), radius: 8, y: 4)
        )
    }
}

// MARK: - New / Edit Journal Entry

struct NewJournalEntryView: View {
    @ObservedObject var journalStore: JournalStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var content: String
    @State private var mood: JournalEntry.Mood
    @State private var selectedMedIDs: Set<UUID>
    @State private var sideEffectText = ""
    @State private var sideEffects: [String]
    @State private var sleepQuality: JournalEntry.SleepQuality?
    @State private var energyLevel: Int
    
    private let editing: JournalEntry?
    
    init(journalStore: JournalStore, medStore: MedicationStore, editing: JournalEntry? = nil) {
        self.journalStore = journalStore
        self.medStore = medStore
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _content = State(initialValue: editing?.content ?? "")
        _mood = State(initialValue: editing?.mood ?? .neutral)
        _selectedMedIDs = State(initialValue: Set(editing?.medicationIDs ?? []))
        _sideEffects = State(initialValue: editing?.sideEffects ?? [])
        _sleepQuality = State(initialValue: editing?.sleepQuality)
        _energyLevel = State(initialValue: editing?.energyLevel ?? 3)
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    moodSelector(color: color)
                    titleAndContent
                    medicationLinker(color: color)
                    sideEffectsSection(color: color)
                    wellnessSection(color: color)
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
            .navigationTitle(editing != nil ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.isEmpty)
                }
            }
        }
    }
    
    private func saveEntry() {
        if var existing = editing {
            existing.mood = mood
            existing.title = title
            existing.content = content
            existing.medicationIDs = Array(selectedMedIDs)
            existing.sideEffects = sideEffects
            existing.sleepQuality = sleepQuality
            existing.energyLevel = energyLevel
            journalStore.update(existing)
        } else {
            let entry = JournalEntry(
                date: .now,
                mood: mood,
                title: title,
                content: content,
                medicationIDs: Array(selectedMedIDs),
                sideEffects: sideEffects,
                sleepQuality: sleepQuality,
                energyLevel: energyLevel
            )
            journalStore.add(entry)
        }
    }
    
    // MARK: - Mood Selector
    
    private func moodSelector(color: Color) -> some View {
        VStack(spacing: 10) {
            Text("How are you feeling?")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(JournalEntry.Mood.allCases, id: \.self) { m in
                    let isSelected = mood == m
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            mood = m
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(m.emoji)
                                .font(isSelected ? .largeTitle : .title2)
                            Text(m.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? m.color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? m.color.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? m.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Title & Content
    
    private var titleAndContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title (optional)", text: $title)
                .font(.headline)
            
            Divider()
            
            TextField("Write about how you're feeling today...", text: $content, axis: .vertical)
                .font(.body)
                .lineLimit(5...15)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Medication Linker
    
    private func medicationLinker(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Link Medications", systemImage: "pills.fill")
                .font(.subheadline.weight(.semibold))
            
            if medStore.medications.isEmpty {
                Text("No medications added yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(medStore.medications) { med in
                        let isSelected = selectedMedIDs.contains(med.id)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isSelected {
                                    selectedMedIDs.remove(med.id)
                                } else {
                                    selectedMedIDs.insert(med.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(med.color.color)
                                    .frame(width: 8, height: 8)
                                Text(med.name)
                                    .font(.caption.weight(.medium))
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill)
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    isSelected ? color : .clear, lineWidth: 1.5
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Side Effects
    
    private func sideEffectsSection(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Side Effects", systemImage: "exclamationmark.bubble.fill")
                .font(.subheadline.weight(.semibold))
            
            HStack {
                TextField("e.g. nausea, headache...", text: $sideEffectText)
                    .font(.subheadline)
                
                Button {
                    let trimmed = sideEffectText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    sideEffects.append(trimmed)
                    sideEffectText = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .disabled(sideEffectText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if !sideEffects.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(sideEffects, id: \.self) { effect in
                        HStack(spacing: 4) {
                            Text(effect)
                                .font(.caption.weight(.medium))
                            Button {
                                sideEffects.removeAll { $0 == effect }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Wellness
    
    private func wellnessSection(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sleep
            VStack(alignment: .leading, spacing: 8) {
                Label("Sleep Quality", systemImage: "moon.stars.fill")
                    .font(.subheadline.weight(.semibold))
                
                HStack(spacing: 8) {
                    ForEach(JournalEntry.SleepQuality.allCases, id: \.self) { sq in
                        let isSelected = sleepQuality == sq
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                sleepQuality = isSelected ? nil : sq
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: sq.icon)
                                    .font(.body)
                                Text(sq.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? color.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? color : .secondary)
                    }
                }
            }
            
            Divider()
            
            // Energy
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Energy Level", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(energyLevel)/5")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                energyLevel = level
                            }
                        } label: {
                            Image(systemName: level <= energyLevel ? "bolt.fill" : "bolt")
                                .font(.title3)
                                .foregroundStyle(level <= energyLevel ? color : .secondary.opacity(0.4))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Summary Report View

struct SummaryReportView: View {
    @ObservedObject var journalStore: JournalStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var timeRange: TimeRange = .twoWeeks
    
    enum TimeRange: String, CaseIterable {
        case oneWeek = "1 Week"
        case twoWeeks = "2 Weeks"
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        
        var days: Int {
            switch self {
            case .oneWeek: return 7
            case .twoWeeks: return 14
            case .oneMonth: return 30
            case .threeMonths: return 90
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generatePDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(rangeEntries.isEmpty)
                }
            }
        }
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF() {
        let entries = rangeEntries
        guard !entries.isEmpty else { return }
        
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let data = pdfRenderer.pdfData { context in
            var yPos: CGFloat = 0
            
            func newPage() {
                context.beginPage()
                yPos = margin
            }
            
            func checkSpace(_ needed: CGFloat) {
                if yPos + needed > pageHeight - margin {
                    newPage()
                }
            }
            
            func drawText(_ text: String, fontSize: CGFloat, bold: Bool = false, color: UIColor = .black, maxWidth: CGFloat? = nil) {
                let font: UIFont = bold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let w = maxWidth ?? contentWidth
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: w, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                checkSpace(boundingRect.height + 4)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: yPos, width: w, height: boundingRect.height),
                    withAttributes: attrs
                )
                yPos += boundingRect.height + 4
            }
            
            func drawLine() {
                checkSpace(10)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPos))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                yPos += 10
            }
            
            func drawRow(_ label: String, _ value: String) {
                let font = UIFont.systemFont(ofSize: 11)
                let boldFont = UIFont.boldSystemFont(ofSize: 11)
                checkSpace(18)
                (label as NSString).draw(
                    at: CGPoint(x: margin, y: yPos),
                    withAttributes: [.font: font, .foregroundColor: UIColor.darkGray]
                )
                (value as NSString).draw(
                    at: CGPoint(x: pageWidth - margin - 120, y: yPos),
                    withAttributes: [.font: boldFont, .foregroundColor: UIColor.black]
                )
                yPos += 18
            }
            
            // Page 1
            newPage()
            
            // Header
            drawText("Medication & Wellness Report", fontSize: 22, bold: true)
            yPos += 4
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let today = dateFormatter.string(from: .now)
            drawText("Generated: \(today)  •  Period: \(timeRange.rawValue)", fontSize: 10, color: .gray)
            yPos += 8
            drawLine()
            yPos += 4
            
            // Overview
            let avgMood = Double(entries.map(\.mood.numericValue).reduce(0, +)) / Double(entries.count)
            let avgEnergy = Double(entries.map(\.energyLevel).reduce(0, +)) / Double(entries.count)
            
            drawText("Overview", fontSize: 16, bold: true)
            yPos += 2
            drawRow("Total Entries:", "\(entries.count)")
            drawRow("Average Mood:", String(format: "%.1f / 5", avgMood))
            drawRow("Average Energy:", String(format: "%.1f / 5", avgEnergy))
            
            let sleepEntries = entries.compactMap(\.sleepQuality)
            if !sleepEntries.isEmpty {
                let sleepCounts = Dictionary(grouping: sleepEntries, by: { $0 })
                if let mostCommon = sleepCounts.max(by: { $0.value.count < $1.value.count }) {
                    drawRow("Typical Sleep:", mostCommon.key.rawValue)
                }
            }
            yPos += 8
            drawLine()
            yPos += 4
            
            // Mood Distribution
            drawText("Mood Distribution", fontSize: 16, bold: true)
            yPos += 2
            let total = Double(entries.count)
            for mood in JournalEntry.Mood.allCases {
                let count = entries.filter { $0.mood == mood }.count
                let pct = total > 0 ? Double(count) / total * 100 : 0
                drawRow("\(mood.emoji) \(mood.rawValue):", "\(count) (\(String(format: "%.0f", pct))%)")
            }
            yPos += 8
            drawLine()
            yPos += 4
            
            // Per-medication breakdown
            let medsWithEntries = medStore.medications.filter { med in
                entries.contains { $0.medicationIDs.contains(med.id) }
            }
            if !medsWithEntries.isEmpty {
                drawText("By Medication", fontSize: 16, bold: true)
                yPos += 2
                for med in medsWithEntries {
                    let medEntries = entries.filter { $0.medicationIDs.contains(med.id) }
                    let medAvgMood = Double(medEntries.map(\.mood.numericValue).reduce(0, +)) / Double(medEntries.count)
                    let effects = Array(Set(medEntries.flatMap(\.sideEffects)))
                    
                    drawText("\(med.name) (\(med.dosage))", fontSize: 12, bold: true)
                    drawRow("  Entries:", "\(medEntries.count)")
                    drawRow("  Avg Mood:", String(format: "%.1f / 5", medAvgMood))
                    if !effects.isEmpty {
                        drawText("  Side effects: \(effects.joined(separator: ", "))", fontSize: 10, color: .orange)
                    }
                    yPos += 4
                }
                yPos += 4
                drawLine()
                yPos += 4
            }
            
            // Side effects
            let allEffects = entries.flatMap(\.sideEffects)
            let groupedEffects = Dictionary(grouping: allEffects, by: { $0.lowercased() })
                .sorted { $0.value.count > $1.value.count }
            if !groupedEffects.isEmpty {
                drawText("Reported Side Effects", fontSize: 16, bold: true)
                yPos += 2
                for effect in groupedEffects.prefix(10) {
                    drawRow("  \(effect.key.capitalized):", "\(effect.value.count) occurrences")
                }
                yPos += 8
                drawLine()
                yPos += 4
            }
            
            // Notable entries
            let notable = entries.filter {
                $0.mood == .veryBad || $0.mood == .veryGood || !$0.sideEffects.isEmpty
            }.prefix(8)
            if !notable.isEmpty {
                drawText("Notable Entries", fontSize: 16, bold: true)
                yPos += 2
                drawText("Entries with extreme moods or reported side effects:", fontSize: 10, color: .gray)
                yPos += 4
                for entry in notable {
                    let date = entry.date.formatted(.dateTime.month(.abbreviated).day().year())
                    let title = entry.title.isEmpty ? "" : " — \(entry.title)"
                    drawText("\(entry.mood.emoji) \(date)\(title)", fontSize: 11, bold: true)
                    let preview = String(entry.content.prefix(200))
                    drawText("  \"\(preview)\"", fontSize: 10, color: .darkGray)
                    if !entry.sideEffects.isEmpty {
                        drawText("  Side effects: \(entry.sideEffects.joined(separator: ", "))", fontSize: 9, color: .orange)
                    }
                    yPos += 6
                }
            }
            
            // Footer
            checkSpace(40)
            yPos += 10
            drawLine()
            drawText("This report was generated by MedTracker for informational purposes. Share with your healthcare provider for clinical evaluation.", fontSize: 8, color: .gray)
        }
        
        // Save and share
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MedTracker_Report_\(timeRange.rawValue.replacingOccurrences(of: " ", with: "_")).pdf")
        do {
            try data.write(to: tempURL)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var presenter = rootVC
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                activityVC.popoverPresentationController?.sourceView = presenter.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: 0, width: 0, height: 0)
                presenter.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to save PDF: \(error)")
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
