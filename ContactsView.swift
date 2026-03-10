import SwiftUI

// MARK: - Support Contact Model

struct SupportContact: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var relationship: String    // e.g. "Therapist", "Mom", "Sponsor"
    var note: String            // e.g. "Available evenings", "Call anytime"
    var isFavorite: Bool = false
    var colorHex: String = "#5C6BC0"
    
    var color: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Pharmacy Model

struct Pharmacy: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var address: String
    var hours: String           // e.g. "Mon-Fri 9am-9pm, Sat 10am-6pm"
    var note: String            // e.g. "Auto-refill enabled", "Rx #12345"
    var colorHex: String = "#26A69A"
    
    var color: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Contact Store

@MainActor
class ContactStore: ObservableObject {
    @Published var contacts: [SupportContact] = []
    
    private let saveKey = "saved_support_contacts"
    
    init() {
        load()
    }
    
    func add(_ contact: SupportContact) {
        contacts.append(contact)
        save()
    }
    
    func update(_ contact: SupportContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            save()
        }
    }
    
    func delete(_ contact: SupportContact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }
    
    func toggleFavorite(_ contact: SupportContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index].isFavorite.toggle()
            save()
        }
    }
    
    var favorites: [SupportContact] {
        contacts.filter(\.isFavorite)
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([SupportContact].self, from: data) else { return }
        contacts = decoded
    }
}

// MARK: - Pharmacy Store

@MainActor
class PharmacyStore: ObservableObject {
    @Published var pharmacies: [Pharmacy] = []
    
    private let saveKey = "saved_pharmacies"
    
    init() { load() }
    
    func add(_ pharmacy: Pharmacy) {
        pharmacies.append(pharmacy)
        save()
    }
    
    func update(_ pharmacy: Pharmacy) {
        if let index = pharmacies.firstIndex(where: { $0.id == pharmacy.id }) {
            pharmacies[index] = pharmacy
            save()
        }
    }
    
    func delete(_ pharmacy: Pharmacy) {
        pharmacies.removeAll { $0.id == pharmacy.id }
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(pharmacies) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Pharmacy].self, from: data) else { return }
        pharmacies = decoded
    }
}

// MARK: - Support Contacts View

struct ContactsView: View {
    @ObservedObject var contactStore: ContactStore
    @ObservedObject var medStore: MedicationStore
    @ObservedObject var pharmacyStore: PharmacyStore
    
    @State private var showCrisisMode = false
    @State private var activeSheet: ContactsSheet? = nil
    
    enum ContactsSheet: Identifiable {
        case addContact
        case editContact(SupportContact)
        case addPharmacy
        case editPharmacy(Pharmacy)
        
        var id: String {
            switch self {
            case .addContact: return "addContact"
            case .editContact(let c): return "editContact-\(c.id)"
            case .addPharmacy: return "addPharmacy"
            case .editPharmacy(let p): return "editPharmacy-\(p.id)"
            }
        }
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [color.opacity(0.12), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if contactStore.contacts.isEmpty && pharmacyStore.pharmacies.isEmpty {
                    emptyState(color: color)
                } else {
                    List {
                        Section {
                            crisisButton(color: color)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        
                        if !contactStore.favorites.isEmpty {
                            Section {
                                quickCallSection(color: color)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        
                        if !contactStore.contacts.isEmpty {
                            Section {
                                ForEach(contactStore.contacts) { contact in
                                    contactRow(contact, color: color)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text("All Contacts")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        
                        // Pharmacy Section
                        Section {
                            pharmacySection(color: color)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        
                        Section {
                            hotlinesCard(color: color)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Support")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .addContact
                        } label: {
                            Label("Add Contact", systemImage: "person.badge.plus")
                        }
                        
                        Button {
                            activeSheet = .addPharmacy
                        } label: {
                            Label("Add Pharmacy", systemImage: "cross.vial.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(color)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addContact:
                    AddContactView(contactStore: contactStore, medStore: medStore)
                case .editContact(let contact):
                    AddContactView(contactStore: contactStore, medStore: medStore, editing: contact)
                case .addPharmacy:
                    AddPharmacyView(pharmacyStore: pharmacyStore, medStore: medStore)
                case .editPharmacy(let pharmacy):
                    AddPharmacyView(pharmacyStore: pharmacyStore, medStore: medStore, editing: pharmacy)
                }
            }
            .fullScreenCover(isPresented: $showCrisisMode) {
                CrisisModeView(contactStore: contactStore, medStore: medStore)
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyState(color: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(color.opacity(0.4))
            
            Text("Your Support Network")
                .font(.title3.weight(.bold))
            
            Text("Add people you trust — therapists, family, friends — and your pharmacies so you can reach them quickly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            HStack(spacing: 12) {
                Button {
                    activeSheet = .addContact
                } label: {
                    Text("Add Contact")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
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
                
                Button {
                    activeSheet = .addPharmacy
                } label: {
                    Text("Add Pharmacy")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(color, lineWidth: 1.5)
                        )
                }
            }
            
            // Always show hotlines even with no contacts
            hotlinesCard(color: color)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Crisis Button
    
    private func crisisButton(color: Color) -> some View {
        Button {
            showCrisisMode = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("I Need Help Now")
                        .font(.headline)
                    Text("Quick access to your support network")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.85), Color.red.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: .red.opacity(0.3), radius: 10, y: 5)
        }
    }
    
    // MARK: - Quick Call (Favorites)
    
    private func quickCallSection(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Call")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(contactStore.favorites) { contact in
                        quickCallBubble(contact, color: color)
                    }
                }
            }
        }
    }
    
    private func quickCallBubble(_ contact: SupportContact, color: Color) -> some View {
        Button {
            callContact(contact)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(contact.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Text(contact.initials)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(contact.color)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.green))
                        .offset(x: 2, y: 2)
                }
                
                Text(contact.name.split(separator: " ").first.map(String.init) ?? contact.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(contact.relationship)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Contact Row
    
    private func contactRow(_ contact: SupportContact, color: Color) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(contact.color.opacity(0.15))
                    .frame(width: 46, height: 46)
                
                Text(contact.initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(contact.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.subheadline.weight(.semibold))
                    
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text(contact.relationship)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !contact.note.isEmpty {
                    Text(contact.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    sendMessage(to: contact)
                } label: {
                    Image(systemName: "message.fill")
                        .font(.body)
                        .foregroundStyle(color.opacity(0.6))
                }
                
                Button {
                    callContact(contact)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.06), radius: 6, y: 3)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { contactStore.delete(contact) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                contactStore.toggleFavorite(contact)
            } label: {
                Label(
                    contact.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: contact.isFavorite ? "star.slash" : "star.fill"
                )
            }
            .tint(.yellow)
            
            Button {
                activeSheet = .editContact(contact)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    // MARK: - Pharmacy Section
    
    private func pharmacySection(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.vial.fill")
                    .foregroundStyle(color)
                Text("My Pharmacies")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    activeSheet = .addPharmacy
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(color)
                }
            }
            
            if pharmacyStore.pharmacies.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.secondary)
                    Text("Add your pharmacy for quick refill calls")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(pharmacyStore.pharmacies) { pharmacy in
                    pharmacyRow(pharmacy, color: color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private func pharmacyRow(_ pharmacy: Pharmacy, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(pharmacy.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "cross.vial.fill")
                    .font(.caption)
                    .foregroundStyle(pharmacy.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pharmacy.name)
                    .font(.subheadline.weight(.semibold))
                
                if !pharmacy.hours.isEmpty {
                    Text(pharmacy.hours)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if !pharmacy.address.isEmpty {
                    Text(pharmacy.address)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                if !pharmacy.note.isEmpty {
                    Text(pharmacy.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                if !pharmacy.address.isEmpty {
                    Button {
                        openMaps(for: pharmacy)
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.subheadline)
                            .foregroundStyle(color.opacity(0.6))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.borderless)
                }
                
                Button {
                    callPharmacy(pharmacy)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                
                Menu {
                    Button {
                        activeSheet = .editPharmacy(pharmacy)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        withAnimation { pharmacyStore.delete(pharmacy) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 32)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Hotlines Card
    
    private func hotlinesCard(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "phone.badge.checkmark")
                    .foregroundStyle(color)
                Text("Crisis Hotlines")
                    .font(.headline)
            }
            
            Text("Available 24/7 — free and confidential")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            hotlineRow(
                name: "988 Suicide & Crisis Lifeline",
                number: "988",
                icon: "heart.fill",
                iconColor: .red
            )
            
            hotlineRow(
                name: "Crisis Text Line",
                number: "741741",
                icon: "message.fill",
                iconColor: .blue
            )
            
            hotlineRow(
                name: "SAMHSA Helpline",
                number: "1-800-662-4357",
                icon: "cross.fill",
                iconColor: .green
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private func hotlineRow(name: String, number: String, icon: String, iconColor: Color) -> some View {
        Button {
            let cleaned = number.replacingOccurrences(of: "-", with: "")
            if let url = URL(string: "tel://\(cleaned)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(number)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "phone.arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Phone Actions
    
    private func callContact(_ contact: SupportContact) {
        let cleaned = contact.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendMessage(to contact: SupportContact) {
        let cleaned = contact.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "sms://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func callPharmacy(_ pharmacy: Pharmacy) {
        let cleaned = pharmacy.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMaps(for pharmacy: Pharmacy) {
        let encoded = pharmacy.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Crisis Mode (Full Screen)

struct CrisisModeView: View {
    @ObservedObject var contactStore: ContactStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var breathePhase: BreathPhase = .inhale
    @State private var breatheTimer: Timer? = nil
    @State private var showContacts = true
    
    enum BreathPhase: String {
        case inhale = "Breathe In"
        case hold = "Hold"
        case exhale = "Breathe Out"
        
        var duration: Double {
            switch self {
            case .inhale: return 4
            case .hold: return 4
            case .exhale: return 6
            }
        }
        
        var next: BreathPhase {
            switch self {
            case .inhale: return .hold
            case .hold: return .exhale
            case .exhale: return .inhale
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Calming background
            LinearGradient(
                colors: [Color.indigo.opacity(0.3), Color.blue.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        breatheTimer?.invalidate()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Breathing exercise
                breathingCircle
                
                // Quick contacts
                if showContacts {
                    contactsList
                }
                
                // Hotlines always visible
                crisisHotlines
                
                Spacer()
            }
            .padding(.top)
        }
        .onAppear { startBreathing() }
        .onDisappear { breatheTimer?.invalidate() }
    }
    
    // MARK: - Breathing Circle
    
    private var breathingCircle: some View {
        VStack(spacing: 12) {
            Text("You're going to be okay")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                            center: .center,
                            startRadius: 20,
                            endRadius: breathePhase == .exhale ? 40 : 70
                        )
                    )
                    .frame(
                        width: breathePhase == .exhale ? 100 : 140,
                        height: breathePhase == .exhale ? 100 : 140
                    )
                    .animation(.easeInOut(duration: breathePhase.duration), value: breathePhase)
                
                VStack(spacing: 4) {
                    Text(breathePhase.rawValue)
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text("\(Int(breathePhase.duration))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
        }
    }
    
    // MARK: - Quick Contacts List
    
    private var contactsList: some View {
        VStack(spacing: 10) {
            let contactsToShow = contactStore.favorites.isEmpty ? Array(contactStore.contacts.prefix(4)) : contactStore.favorites
            
            if !contactsToShow.isEmpty {
                Text("Reach Out")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                ForEach(contactsToShow) { contact in
                    crisisContactRow(contact)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func crisisContactRow(_ contact: SupportContact) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(contact.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(contact.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(contact.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.subheadline.weight(.semibold))
                Text(contact.relationship)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button {
                    let cleaned = contact.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "sms://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "message.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.blue))
                }
                
                Button {
                    let cleaned = contact.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.green))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Crisis Hotlines
    
    private var crisisHotlines: some View {
        VStack(spacing: 8) {
            Text("Crisis Lines — 24/7")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                crisisHotlineButton(label: "988", subtitle: "Crisis Line", number: "988")
                crisisHotlineButton(label: "Text", subtitle: "741741", number: "741741")
            }
            .padding(.horizontal)
        }
    }
    
    private func crisisHotlineButton(label: String, subtitle: String, number: String) -> some View {
        Button {
            let cleaned = number.replacingOccurrences(of: "-", with: "")
            if let url = URL(string: "tel://\(cleaned)") {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(spacing: 3) {
                Text(label)
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.caption2)
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(0.75))
            )
        }
    }
    
    // MARK: - Breathing Timer
    
    private func startBreathing() {
        breatheTimer?.invalidate()
        breatheTimer = Timer.scheduledTimer(withTimeInterval: breathePhase.duration, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.5)) {
                    breathePhase = breathePhase.next
                }
                startBreathing()
            }
        }
    }
}

// MARK: - Add/Edit Contact View

struct AddContactView: View {
    @ObservedObject var contactStore: ContactStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var phone: String
    @State private var relationship: String
    @State private var note: String
    @State private var isFavorite: Bool
    @State private var selectedColorHex: String
    
    private let editing: SupportContact?
    
    private let colorOptions: [(String, Color)] = [
        ("#5C6BC0", .indigo),
        ("#EF5350", .red),
        ("#4CAF50", .green),
        ("#FF9800", .orange),
        ("#AB47BC", .purple),
        ("#26A69A", .teal),
        ("#42A5F5", .blue),
        ("#EC407A", .pink),
    ]
    
    private let relationshipSuggestions = [
        "Therapist", "Psychiatrist", "Doctor", "Counselor",
        "Mom", "Dad", "Sibling", "Partner", "Spouse",
        "Best Friend", "Friend", "Sponsor", "Mentor", "Coach"
    ]
    
    init(contactStore: ContactStore, medStore: MedicationStore, editing: SupportContact? = nil) {
        self.contactStore = contactStore
        self.medStore = medStore
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _phone = State(initialValue: editing?.phone ?? "")
        _relationship = State(initialValue: editing?.relationship ?? "")
        _note = State(initialValue: editing?.note ?? "")
        _isFavorite = State(initialValue: editing?.isFavorite ?? false)
        _selectedColorHex = State(initialValue: editing?.colorHex ?? "#5C6BC0")
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview avatar
                    previewAvatar
                    
                    // Name & Phone
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Name", text: $name)
                            .font(.headline)
                            .textContentType(.name)
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.secondary)
                            TextField("Phone number", text: $phone)
                                .font(.subheadline)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Relationship
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Relationship", systemImage: "person.2.fill")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g. Therapist, Mom, Best Friend...", text: $relationship)
                            .font(.subheadline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(relationshipSuggestions, id: \.self) { suggestion in
                                    Button {
                                        relationship = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule().fill(
                                                    relationship == suggestion ? color.opacity(0.2) : Color(.tertiarySystemFill)
                                                )
                                            )
                                            .foregroundStyle(relationship == suggestion ? color : .secondary)
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
                    
                    // Note
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Note", systemImage: "text.bubble")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g. Available evenings, Call anytime...", text: $note)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Color", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                        
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.0) { hex, swiftColor in
                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(swiftColor)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                                .shadow(color: .black.opacity(0.2), radius: 2)
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Favorite toggle
                    Toggle(isOn: $isFavorite) {
                        Label("Add to Quick Call", systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(color)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
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
            .navigationTitle(editing != nil ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || phone.isEmpty)
                }
            }
        }
    }
    
    private var previewAvatar: some View {
        let previewContact = SupportContact(
            name: name.isEmpty ? "AB" : name,
            phone: "",
            relationship: relationship,
            note: "",
            colorHex: selectedColorHex
        )
        
        return ZStack {
            Circle()
                .fill(previewContact.color.opacity(0.15))
                .frame(width: 72, height: 72)
            
            Text(previewContact.initials)
                .font(.title2.weight(.bold))
                .foregroundStyle(previewContact.color)
        }
    }
    
    private func saveContact() {
        if var existing = editing {
            existing.name = name
            existing.phone = phone
            existing.relationship = relationship
            existing.note = note
            existing.isFavorite = isFavorite
            existing.colorHex = selectedColorHex
            contactStore.update(existing)
        } else {
            let contact = SupportContact(
                name: name,
                phone: phone,
                relationship: relationship,
                note: note,
                isFavorite: isFavorite,
                colorHex: selectedColorHex
            )
            contactStore.add(contact)
        }
    }
}

// MARK: - Add/Edit Pharmacy View

struct AddPharmacyView: View {
    @ObservedObject var pharmacyStore: PharmacyStore
    @ObservedObject var medStore: MedicationStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var phone: String
    @State private var address: String
    @State private var hours: String
    @State private var note: String
    @State private var selectedColorHex: String
    
    private let editing: Pharmacy?
    
    private let colorOptions: [(String, Color)] = [
        ("#26A69A", .teal),
        ("#5C6BC0", .indigo),
        ("#4CAF50", .green),
        ("#42A5F5", .blue),
        ("#FF9800", .orange),
        ("#AB47BC", .purple),
    ]
    
    private let pharmacySuggestions = [
        "CVS Pharmacy", "Walgreens", "Rite Aid", "Costco Pharmacy",
        "Walmart Pharmacy", "Kroger Pharmacy", "Hospital Pharmacy"
    ]
    
    init(pharmacyStore: PharmacyStore, medStore: MedicationStore, editing: Pharmacy? = nil) {
        self.pharmacyStore = pharmacyStore
        self.medStore = medStore
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _phone = State(initialValue: editing?.phone ?? "")
        _address = State(initialValue: editing?.address ?? "")
        _hours = State(initialValue: editing?.hours ?? "")
        _note = State(initialValue: editing?.note ?? "")
        _selectedColorHex = State(initialValue: editing?.colorHex ?? "#26A69A")
    }
    
    var body: some View {
        let color = medStore.accentColor
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    previewAvatar
                    
                    // Name & Phone
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Pharmacy Name", text: $name)
                            .font(.headline)
                        
                        // Quick suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(pharmacySuggestions, id: \.self) { suggestion in
                                    Button {
                                        name = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule().fill(
                                                    name == suggestion ? color.opacity(0.2) : Color(.tertiarySystemFill)
                                                )
                                            )
                                            .foregroundStyle(name == suggestion ? color : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.secondary)
                            TextField("Phone number", text: $phone)
                                .font(.subheadline)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Address
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Address", systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("Street address", text: $address)
                            .font(.subheadline)
                            .textContentType(.fullStreetAddress)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Hours
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Hours", systemImage: "clock.fill")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g. Mon-Fri 9am-9pm, Sat 10am-6pm", text: $hours)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Note
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Note", systemImage: "text.bubble")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g. Auto-refill enabled, Rx #12345", text: $note)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Color", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                        
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.0) { hex, swiftColor in
                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(swiftColor)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                                .shadow(color: .black.opacity(0.2), radius: 2)
                                        )
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
            .navigationTitle(editing != nil ? "Edit Pharmacy" : "New Pharmacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePharmacy()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || phone.isEmpty)
                }
            }
        }
    }
    
    private var previewAvatar: some View {
        let preview = Pharmacy(
            name: name.isEmpty ? "RX" : name,
            phone: "", address: "", hours: "", note: "",
            colorHex: selectedColorHex
        )
        
        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(preview.color.opacity(0.15))
                .frame(width: 72, height: 72)
            
            Image(systemName: "cross.vial.fill")
                .font(.title2)
                .foregroundStyle(preview.color)
        }
    }
    
    private func savePharmacy() {
        if var existing = editing {
            existing.name = name
            existing.phone = phone
            existing.address = address
            existing.hours = hours
            existing.note = note
            existing.colorHex = selectedColorHex
            pharmacyStore.update(existing)
        } else {
            let pharmacy = Pharmacy(
                name: name,
                phone: phone,
                address: address,
                hours: hours,
                note: note,
                colorHex: selectedColorHex
            )
            pharmacyStore.add(pharmacy)
        }
    }
}

