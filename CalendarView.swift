import SwiftUI
import UserNotifications

// MARK: - Models

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dosage: String            // e.g. "500mg"
    var frequency: Frequency
    var timesPerDay: Int          // how many doses per day
    var currentStock: Int         // pills/doses remaining
    var lowStockThreshold: Int    // notify when stock drops to this
    var color: CodableColor
    var notes: String
    var startDate: Date
    var takenDates: [Date]        // dates (startOfDay) when medication was taken
    
    var isLowStock: Bool {
        currentStock <= lowStockThreshold
    }
    
    /// Estimated days until medication runs out
    var daysUntilEmpty: Int {
        guard timesPerDay > 0 else { return Int.max }
        let dailyUsage: Double
        switch frequency {
        case .daily:
            dailyUsage = Double(timesPerDay)
        case .everyOtherDay:
            dailyUsage = Double(timesPerDay) / 2.0
        case .weekly:
            dailyUsage = Double(timesPerDay) / 7.0
        case .asNeeded:
            return Int.max
        }
        guard dailyUsage > 0 else { return Int.max }
        return Int(Double(currentStock) / dailyUsage)
    }
    
    /// Check if this medication is scheduled for a given date
    func isScheduled(for date: Date) -> Bool {
        let cal = Calendar.current
        guard date >= cal.startOfDay(for: startDate) else { return false }
        switch frequency {
        case .daily:
            return true
        case .everyOtherDay:
            let daysBetween = cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: date)).day ?? 0
            return daysBetween % 2 == 0
        case .weekly:
            return cal.component(.weekday, from: date) == cal.component(.weekday, from: startDate)
        case .asNeeded:
            return false
        }
    }
    
    func wasTaken(on date: Date) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        return takenDates.contains { Calendar.current.startOfDay(for: $0) == start }
    }
    
    enum Frequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case everyOtherDay = "Every Other Day"
        case weekly = "Weekly"
        case asNeeded = "As Needed"
    }
}

/// Wraps Color for Codable support
struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
    
    static let presets: [(name: String, color: CodableColor)] = [
        ("Blue",   CodableColor(red: 0.25, green: 0.47, blue: 0.85)),
        ("Purple", CodableColor(red: 0.55, green: 0.30, blue: 0.85)),
        ("Teal",   CodableColor(red: 0.20, green: 0.70, blue: 0.65)),
        ("Orange", CodableColor(red: 0.90, green: 0.50, blue: 0.20)),
        ("Pink",   CodableColor(red: 0.85, green: 0.30, blue: 0.50)),
        ("Green",  CodableColor(red: 0.30, green: 0.70, blue: 0.35)),
    ]
}

// MARK: - Medication Store

@MainActor
class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var accentColor: Color = .blue 
    private let saveKey = "saved_medications"
    
    init() {
        load()
    }
    
    func add(_ med: Medication) {
        medications.append(med)
        save()
        scheduleLowStockNotifications()
    }
    
    func update(_ med: Medication) {
        if let index = medications.firstIndex(where: { $0.id == med.id }) {
            medications[index] = med
            save()
            scheduleLowStockNotifications()
        }
    }
    
    func delete(_ med: Medication) {
        medications.removeAll { $0.id == med.id }
        save()
    }
    
    func markTaken(_ med: Medication, on date: Date) {
        guard var updated = medications.first(where: { $0.id == med.id }) else { return }
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        if updated.wasTaken(on: date) {
            // Undo: remove the taken date and restore stock
            updated.takenDates.removeAll { Calendar.current.startOfDay(for: $0) == startOfDay }
            updated.currentStock += updated.timesPerDay
        } else {
            updated.takenDates.append(startOfDay)
            updated.currentStock = max(0, updated.currentStock - updated.timesPerDay)
        }
        
        update(updated)
    }
    
    func medications(for date: Date) -> [Medication] {
        medications.filter { $0.isScheduled(for: date) }
    }
    
    func lowStockMedications() -> [Medication] {
        medications.filter { $0.isLowStock }
    }
    
    // MARK: Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(medications) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Medication].self, from: data) else { return }
        medications = decoded
    }
    
    // MARK: Notifications
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    func scheduleLowStockNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: medications.map { "lowstock-\($0.id)" })
        
        for med in medications where med.isLowStock {
            let content = UNMutableNotificationContent()
            content.title = "Low Stock: \(med.name)"
            content.body = "You have \(med.currentStock) \(med.dosage) remaining (~\(med.daysUntilEmpty) days). Time to refill!"
            content.sound = .default
            
            // Notify at 9 AM tomorrow
            var dateComponents = DateComponents()
            dateComponents.hour = 9
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "lowstock-\(med.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}

// MARK: - Main App View

struct MedCalendarView: View {
    @ObservedObject var store: MedicationStore
    @State private var accentColor: Color = .blue
    @State private var date = Date.now
    @State private var days: [Date] = []
    @State private var selectedDay: Date? = nil
    @State private var showAddMedication = false
    @State private var showMedicationList = false
    
    private let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        if #available(iOS 17.0, *) {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 20) {
                        monthHeader
                        lowStockBanner
                        weekdayHeaders
                        calendarGrid
                        selectedDayDetail
                        controlsCard
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                
                // Floating Action Buttons
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Spacer()
                        
                        Button {
                            showMedicationList = true
                        } label: {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(store.accentColor.opacity(0.8), in: Circle())
                                .shadow(color: store.accentColor.opacity(0.4), radius: 8, y: 4)
                        }
                        
                        Button {
                            showAddMedication = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [accentColor, store.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Circle()
                                )
                                .shadow(color: store.accentColor.opacity(0.5), radius: 10, y: 5)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                days = date.calendarDisplayDays
                store.requestNotificationPermission()
            }
            .onChange(of: date) {
                days = date.calendarDisplayDays
                selectedDay = nil
            }
            .sheet(isPresented: $showAddMedication) {
                AddMedicationView(store: store, accentColor: store.accentColor)
            }
            .sheet(isPresented: $showMedicationList) {
                MedicationListView(store: store, accentColor: store.accentColor)
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                store.accentColor.opacity(0.15),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Low Stock Banner
    
    @ViewBuilder
    private var lowStockBanner: some View {
        let lowStock = store.lowStockMedications()
        if !lowStock.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Low Stock Alert", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                
                ForEach(lowStock) { med in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(med.color.color)
                            .frame(width: 8, height: 8)
                        Text(med.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(med.currentStock) left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if med.daysUntilEmpty < Int.max {
                            Text("(~\(med.daysUntilEmpty)d)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.year()))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Text(date.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(store.accentColor)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        date = Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(store.accentColor)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        date = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundStyle(store.accentColor)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Weekday Headers
    
    private var weekdayHeaders: some View {
        HStack {
            ForEach(daysOfWeek.indices, id: \.self) { index in
                Text(daysOfWeek[index])
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(store.accentColor.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { day in
                if day.monthInt != date.monthInt {
                    Text("")
                        .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    dayCell(for: day)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Day Cell
    
    private func dayCell(for day: Date) -> some View {
        let isToday = Date.now.startOfDay == day.startOfDay
        let isSelected = selectedDay?.startOfDay == day.startOfDay
        let medsForDay = store.medications(for: day)
        let allTaken = !medsForDay.isEmpty && medsForDay.allSatisfy { $0.wasTaken(on: day) }
        
        return VStack(spacing: 2) {
            Text(day.formatted(.dateTime.day()))
                .font(.system(.callout, design: .rounded))
                .fontWeight(isToday ? .black : .semibold)
                .foregroundStyle(
                    isToday || isSelected ? .white : .primary
                )
            
            // Medication dots
            if !medsForDay.isEmpty {
                HStack(spacing: 2) {
                    ForEach(medsForDay.prefix(3)) { med in
                        Circle()
                            .fill(med.wasTaken(on: day) ? med.color.color : med.color.color.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                    if medsForDay.count > 3 {
                        Text("+")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [store.accentColor, store.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: store.accentColor.opacity(0.4), radius: 6, y: 3)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(store.accentColor.opacity(0.6))
                        .shadow(color: store.accentColor.opacity(0.3), radius: 4, y: 2)
                } else if allTaken {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.green.opacity(0.1))
                }
            }
        )
        .overlay(
            // Checkmark for fully completed days
            Group {
                if allTaken && !isToday && !isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                        .offset(x: 14, y: -16)
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDay = day
            }
        }
    }
    
    // MARK: - Selected Day Detail
    
    @ViewBuilder
    private var selectedDayDetail: some View {
        if let selected = selectedDay {
            let medsForDay = store.medications(for: selected)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.headline)
                        .foregroundStyle(store.accentColor)
                    Spacer()
                    if !medsForDay.isEmpty {
                        let taken = medsForDay.filter { $0.wasTaken(on: selected) }.count
                        Text("\(taken)/\(medsForDay.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if medsForDay.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "pills")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No medications scheduled")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    ForEach(medsForDay) { med in
                        medicationRow(med, on: selected)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func medicationRow(_ med: Medication, on date: Date) -> some View {
        let taken = med.wasTaken(on: date)
        
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(med.color.color)
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(taken, color: .secondary)
                Text("\(med.dosage) · \(med.frequency.rawValue) · \(med.timesPerDay)x/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if med.isLowStock {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.markTaken(med, on: date)
                }
            } label: {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(taken ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Controls Card
    
    private var controlsCard: some View {
        VStack(spacing: 16) {
            LabeledContent {
                ColorPicker("", selection: $store.accentColor, supportsOpacity: false)
            } label: {
                Label("Theme", systemImage: "paintpalette.fill")
                    .foregroundStyle(.primary)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            LabeledContent {
                DatePicker("", selection: $date, displayedComponents: .date)
            } label: {
                Label("Date", systemImage: "calendar")
                    .foregroundStyle(.primary)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
        )
    }
}

// MARK: - Add Medication View

struct AddMedicationView: View {
    @ObservedObject var store: MedicationStore
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: Medication.Frequency = .daily
    @State private var timesPerDay = 1
    @State private var currentStock = 30
    @State private var lowStockThreshold = 7
    @State private var selectedColorIndex = 0
    @State private var notes = ""
    @State private var startDate = Date.now
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Medication Name", text: $name)
                    TextField("Dosage (e.g. 500mg)", text: $dosage)
                    
                    HStack(spacing: 12) {
                        Text("Color")
                        Spacer()
                        ForEach(CodableColor.presets.indices, id: \.self) { i in
                            Circle()
                                .fill(CodableColor.presets[i].color.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == i ? 2 : 0)
                                        .padding(-2)
                                )
                                .onTapGesture { selectedColorIndex = i }
                        }
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Medication.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    Stepper("Doses per day: \(timesPerDay)", value: $timesPerDay, in: 1...10)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                } header: {
                    Text("Schedule")
                }
                
                Section {
                    Stepper("Current Stock: \(currentStock)", value: $currentStock, in: 0...999)
                    Stepper("Low Stock Alert: \(lowStockThreshold)", value: $lowStockThreshold, in: 1...100)
                    
                    if currentStock > 0 && frequency != .asNeeded {
                        let med = buildMedication()
                        if med.daysUntilEmpty < Int.max {
                            HStack {
                                Text("Estimated supply")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("~\(med.daysUntilEmpty) days")
                                    .fontWeight(.medium)
                                    .foregroundStyle(med.isLowStock ? .orange : .green)
                            }
                        }
                    }
                } header: {
                    Text("Stock")
                } footer: {
                    Text("You'll get a notification when your stock drops to \(lowStockThreshold) or below.")
                }
                
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.add(buildMedication())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || dosage.isEmpty)
                }
            }
        }
    }
    
    private func buildMedication() -> Medication {
        Medication(
            name: name,
            dosage: dosage,
            frequency: frequency,
            timesPerDay: timesPerDay,
            currentStock: currentStock,
            lowStockThreshold: lowStockThreshold,
            color: CodableColor.presets[selectedColorIndex].color,
            notes: notes,
            startDate: startDate,
            takenDates: []
        )
    }
}

// MARK: - Medication List View

struct MedicationListView: View {
    @ObservedObject var store: MedicationStore
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var editingMedication: Medication? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if store.medications.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Medications",
                            systemImage: "pills",
                            description: Text("Tap + to add your first medication.")
                        )
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    List {
                        if !store.lowStockMedications().isEmpty {
                            Section("Needs Refill") {
                                ForEach(store.lowStockMedications()) { med in
                                    medicationListRow(med, urgent: true)
                                }
                            }
                        }
                        
                        Section("All Medications") {
                            ForEach(store.medications) { med in
                                medicationListRow(med, urgent: false)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    store.delete(store.medications[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingMedication) { med in
                EditMedicationView(store: store, medication: med)
            }
        }
    }
    
    private func medicationListRow(_ med: Medication, urgent: Bool) -> some View {
        Button {
            editingMedication = med
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(med.color.color)
                    .frame(width: 6, height: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(med.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(med.dosage) · \(med.frequency.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(med.currentStock) left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(med.isLowStock ? .orange : .primary)
                    if med.daysUntilEmpty < Int.max {
                        Text("~\(med.daysUntilEmpty) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if med.isLowStock {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Edit Medication View

struct EditMedicationView: View {
    @ObservedObject var store: MedicationStore
    @State var medication: Medication
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedColorIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $medication.name)
                    TextField("Dosage", text: $medication.dosage)
                    
                    HStack(spacing: 12) {
                        Text("Color")
                        Spacer()
                        ForEach(CodableColor.presets.indices, id: \.self) { i in
                            Circle()
                                .fill(CodableColor.presets[i].color.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == i ? 2 : 0)
                                        .padding(-2)
                                )
                                .onTapGesture {
                                    selectedColorIndex = i
                                    medication.color = CodableColor.presets[i].color
                                }
                        }
                    }
                }
                
                Section("Schedule") {
                    Picker("Frequency", selection: $medication.frequency) {
                        ForEach(Medication.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    Stepper("Doses per day: \(medication.timesPerDay)", value: $medication.timesPerDay, in: 1...10)
                }
                
                Section("Stock") {
                    Stepper("Current Stock: \(medication.currentStock)", value: $medication.currentStock, in: 0...999)
                    Stepper("Low Stock Alert: \(medication.lowStockThreshold)", value: $medication.lowStockThreshold, in: 1...100)
                    
                    // Quick refill button
                    Button {
                        medication.currentStock += 30
                    } label: {
                        Label("Quick Refill (+30)", systemImage: "arrow.clockwise")
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $medication.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(role: .destructive) {
                        store.delete(medication)
                        dismiss()
                    } label: {
                        Label("Delete Medication", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.update(medication)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Match the color to a preset index
                if let index = CodableColor.presets.firstIndex(where: {
                    abs($0.color.red - medication.color.red) < 0.01 &&
                    abs($0.color.green - medication.color.green) < 0.01 &&
                    abs($0.color.blue - medication.color.blue) < 0.01
                }) {
                    selectedColorIndex = index
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MedCalendarView(store: MedicationStore())
}
