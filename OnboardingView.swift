//
//  SwiftUIView.swift
//  MedTracker
//
//  Created by Isidoro Flores on 2/28/26.
//

import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @State private var currentPage = 0
    
    var onFinish: () -> Void
    
    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("plus.circle.fill",
         "Add Your Medications",
         "Tap the + button on the home screen to add a medication. Enter the name, dosage, and how often you take it. Set a stock count so you know when to refill.",
         .blue),
        ("checkmark.circle.fill",
         "Log Your Doses",
         "Each day, tap a medication to mark it as taken. Your streak and adherence stats update automatically. Missed a day? You can backfill from the calendar view.",
         .green),
        ("square.and.pencil.circle.fill",
         "Write Journal Entries",
         "Go to the Journal tab and tap + to log your mood, sleep, energy, and any side effects. Link entries to specific medications to track what's working.",
         .purple),
        ("square.and.arrow.up.circle.fill",
         "Share Reports with Your Doctor",
         "Head to Reports to generate a PDF summary of your trends. It pulls from your journal and medication data — just tap Share to send it before your next appointment.",
         .teal),
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.15),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                // Bottom section
                VStack(spacing: 20) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? pages[currentPage].color : Color.secondary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 7, height: index == currentPage ? 10 : 7)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    if currentPage == pages.count - 1 {
                        // Final page — get started button
                        Button {
                            onFinish()
                        } label: {
                            HStack {
                                Text("Get Started")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                pages[currentPage].color,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: pages[currentPage].color.opacity(0.3), radius: 10, y: 5)
                        }
                    }
                    
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .animation(.easeInOut, value: currentPage)
            }
        }
    }
    
    // MARK: - Page Content
    
    private func onboardingPage(_ page: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.color.opacity(0.2), page.color.opacity(0.05)],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(page.color)
                    .modifier(SymbolPulseIfAvailable())
            }
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
}

// MARK: - Root View (replaces direct HomeView in @main)

struct RootView: View {
    @StateObject private var store = MedicationStore()
    @StateObject private var journalStore = JournalStore()
    @StateObject private var contactStore = ContactStore()
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding: Bool
    
    init() {
        let seen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        _showOnboarding = State(initialValue: !seen)
    }
    
    var body: some View {
        if showOnboarding {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.5)) {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
            }
            .transition(.opacity)
        } else {
            HomeView(store: store, journalStore: journalStore, contactStore: contactStore)
                .transition(.opacity)
        }
    }
}

// MARK: - Helpers

private struct SymbolPulseIfAvailable: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .symbolEffect(.pulse, options: .repeating)
        } else {
            content
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        scale = 1.08
                    }
                }
        }
    }
}
