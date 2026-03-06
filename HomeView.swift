import SwiftUI

struct HomeView: View {
    
    @ObservedObject var store: MedicationStore
   
    @State private var selectedTab: Tab = .home
    @State private var showAddMedication = false
    @State private var now = Date.now
    @ObservedObject var journalStore: JournalStore
    @ObservedObject var contactStore: ContactStore
    
    enum Tab: String, CaseIterable {
        case home = "house.fill"
        case calendar = "calendar"
        case medications = "pills.fill"
        case journal = "book"
        case Contacts = "person.3.fill"
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            TabView(selection: $selectedTab) {
                homeTab
                    .tag(Tab.home)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                MedCalendarView(store: store)
                    .tag(Tab.calendar)
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                
                MedicationListView(store: store, accentColor: store.accentColor)
                .tag(Tab.medications)
                .tabItem {
                    Label("Medications", systemImage: "pills.fill")
                }
                JournalView(journalStore: journalStore, medStore: store)
                    .tag(Tab.journal)
                    .tabItem{
                        Label("Journal", systemImage: "book")
                    }
                ContactsView(contactStore: contactStore, medStore: store)
                    .tag(Tab.Contacts)
                    .tabItem {
                        Label("Contacts", systemImage: "person.3.fill")
                    }
            }
            .tint(store.accentColor)
            .onChange(of: selectedTab) { now = Date.now }
        }
    }
    
    // MARK: - Home Tab
    
    private var homeTab: some View {
        ZStack {
            LinearGradient(
                colors: [store.accentColor.opacity(0.15), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                    todayProgressCard
                    
                    if !store.lowStockMedications().isEmpty {
                        refillAlertCard
                    }
                    
                    todayMedicationsCard
                    weeklyOverviewCard
                    quickActionsRow
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView(store: store, accentColor: store.accentColor)
        }
    }
    
    // MARK: - Greeting Header
    
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(store.accentColor)
            
            Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    // MARK: - Today Progress Card
    
    private var todayProgressCard: some View {
        let todayMeds = store.medications(for: now)
        let takenCount = todayMeds.filter { $0.wasTaken(on: now) }.count
        let totalCount = todayMeds.count
        let progress: Double = totalCount > 0 ? Double(takenCount) / Double(totalCount) : 1.0
        
        return HStack(spacing: 20) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(store.accentColor.opacity(0.15), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [store.accentColor, store.accentColor.opacity(0.6), store.accentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    if totalCount > 0 {
                        Text("\(takenCount)/\(totalCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("taken")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(width: 90, height: 90)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Progress")
                    .font(.headline)
                
                if totalCount == 0 {
                    Text("No medications scheduled today. Enjoy your day!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if takenCount == totalCount {
                    Text("All done! You've taken all your medications today.")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Text("\(totalCount - takenCount) medication\(totalCount - takenCount == 1 ? "" : "s") remaining today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Streak
                let streak = calculateStreak()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak)-day streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Refill Alert Card
    
    private var refillAlertCard: some View {
        let lowStock = store.lowStockMedications()
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Refill Needed")
                    .font(.headline)
                Spacer()
                Text("\(lowStock.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.orange))
            }
            
            ForEach(lowStock) { med in
                HStack(spacing: 10) {
                    Circle()
                        .fill(med.color.color)
                        .frame(width: 10, height: 10)
                    
                    Text(med.name)
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(med.currentStock) left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        if med.daysUntilEmpty < Int.max {
                            Text("~\(med.daysUntilEmpty) days supply")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .orange.opacity(0.08), radius: 10, y: 5)
        )
    }
    
    // MARK: - Today's Medications Card
    
    private var todayMedicationsCard: some View {
        let todayMeds = store.medications(for: now)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Medications")
                    .font(.headline)
                Spacer()
                if !todayMeds.isEmpty {
                    Button {
                        selectedTab = .calendar
                    } label: {
                        Text("See Calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.accentColor)
                    }
                }
            }
            
            if todayMeds.isEmpty && store.medications.isEmpty {
                // Onboarding state
                VStack(spacing: 12) {
                    Image(systemName: "pills.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(store.accentColor.opacity(0.5))
                    
                    Text("Add your first medication")
                        .font(.subheadline.weight(.medium))
                    
                    Text("Track your doses, get refill reminders, and build healthy habits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showAddMedication = true
                    } label: {
                        Text("Get Started")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [store.accentColor, store.accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if todayMeds.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Nothing scheduled today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(todayMeds) { med in
                    todayMedRow(med)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private func todayMedRow(_ med: Medication) -> some View {
        let taken = med.wasTaken(on: now)
        
        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.markTaken(med, on: now)
                }
            } label: {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(taken ? .green : store.accentColor.opacity(0.4))
            }
            
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(med.color.color)
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(taken, color: .secondary)
                    .foregroundStyle(taken ? .secondary : .primary)
                
                Text("\(med.dosage) · \(med.timesPerDay)x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if med.isLowStock {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    // MARK: - Weekly Overview Card
    
    private var weeklyOverviewCard: some View {
        let weekDays = getWeekDays()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
            
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let medsForDay = store.medications(for: day)
                    let isToday = Calendar.current.isDateInToday(day)
                    let takenCount = medsForDay.filter { $0.wasTaken(on: day) }.count
                    let total = medsForDay.count
                    let completed = total > 0 && takenCount == total
                    let isPast = day < Calendar.current.startOfDay(for: now) && !isToday
                    
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? store.accentColor : .secondary)
                        
                        ZStack {
                            Circle()
                                .fill(
                                    isToday ? store.accentColor.opacity(0.15) :
                                    completed ? Color.green.opacity(0.1) :
                                    Color.clear
                                )
                                .frame(width: 36, height: 36)
                            
                            if total == 0 {
                                Text(day.formatted(.dateTime.day()))
                                    .font(.caption.weight(isToday ? .bold : .medium))
                                    .foregroundStyle(isToday ? store.accentColor : .secondary)
                            } else if completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.green)
                            } else if isPast && takenCount < total {
                                // Missed
                                ZStack {
                                    Text(day.formatted(.dateTime.day()))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.red.opacity(0.7))
                                    Circle()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 36, height: 36)
                                }
                            } else {
                                Text("\(takenCount)/\(total)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(isToday ? store.accentColor : .primary)
                            }
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
                .shadow(color: store.accentColor.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            quickAction(icon: "plus.circle.fill", title: "Add Med", color: store.accentColor) {
                showAddMedication = true
            }
            quickAction(icon: "calendar.badge.clock", title: "Calendar", color: .purple) {
                selectedTab = .calendar
            }
            quickAction(icon: "list.clipboard.fill", title: "All Meds", color: .teal) {
                selectedTab = .medications
            }
        }
    }
    
    private func quickAction(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: color.opacity(0.08), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func calculateStreak() -> Int {
        guard !store.medications.isEmpty else { return 0 }
        
        var streak = 0
        var daysChecked = 0
        let cal = Calendar.current
        var checkDate = cal.startOfDay(for: now)
        
        // If today isn't complete yet, start from yesterday
        let todayMeds = store.medications(for: checkDate)
        let todayComplete = !todayMeds.isEmpty && todayMeds.allSatisfy { $0.wasTaken(on: checkDate) }
        
        if !todayComplete {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        
        while daysChecked < 365 {
            daysChecked += 1
            let medsForDay = store.medications(for: checkDate)
            if medsForDay.isEmpty {
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
                continue
            }
            
            let allTaken = medsForDay.allSatisfy { $0.wasTaken(on: checkDate) }
            if allTaken {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func getWeekDays() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }
}

// MARK: - App Entry Point (replace your existing @main)

/*
@main
struct MedTrackerApp: App {
    @StateObject private var store = MedicationStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
        }
    }
}
*/

#Preview {
    HomeView(store: MedicationStore(), journalStore: JournalStore(), contactStore: ContactStore())
}
