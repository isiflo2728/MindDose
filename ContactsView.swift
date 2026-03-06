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

// MARK: - Support Contacts View

struct ContactsView: View {
    @ObservedObject var contactStore: ContactStore
    @ObservedObject var medStore: MedicationStore
    
    @State private var showAddContact = false
    @State private var editingContact: SupportContact? = nil
    @State private var showCrisisMode = false
    
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
                
                if contactStore.contacts.isEmpty {
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
                    Button {
                        showAddContact = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(color)
                    }
                }
            }
            .sheet(isPresented: $showAddContact) {
                AddContactView(contactStore: contactStore, medStore: medStore)
            }
            .sheet(item: $editingContact) { contact in
                AddContactView(contactStore: contactStore, medStore: medStore, editing: contact)
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
            
            Text("Add people you trust — therapists, family, friends — so you can reach them quickly during tough moments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showAddContact = true
            } label: {
                Text("Add First Contact")
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
                editingContact = contact
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
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
