import SwiftUI
import SwiftData

/// The app's three parts, one tab each:
/// * **Desks**: the level menu and the puzzles (the tab bar hides while a desk is being played),
/// * **Baby**: Baby Corner (care, Baby Book),
/// * **Deeds**: Good Deeds, the real-world sticker chart that pays into Baby Corner.
/// The menu's baby banner switches to the Baby tab.
struct RootTabView: View {
    enum Tab: Hashable { case desks, baby, deeds }

    @Environment(\.modelContext) private var modelContext
    @State private var tab: Tab = .desks
    @State private var didApplyLaunchFlags = false

    var body: some View {
        TabView(selection: $tab) {
            LevelSelectView(onOpenBaby: { tab = .baby })
                .tabItem { Label("Desks", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.desks)

            BabyNurseryView(isTab: true)
                .tabItem { Label("Baby", systemImage: "teddybear.fill") }
                .tag(Tab.baby)

            GoodDeedsView(isTab: true)
                .tabItem { Label("Deeds", systemImage: "star.fill") }
                .tag(Tab.deeds)
        }
        .tint(Theme.accent)
        .onAppear {
            #if DEBUG
            // Screenshot helpers (MAC_BUILD.md): `-openNursery YES` starts on the Baby tab,
            // `-openGoodDeeds YES` on the Deeds tab (with `-babyName` / `-babyMonths` applied first).
            guard !didApplyLaunchFlags else { return }
            didApplyLaunchFlags = true
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "openGoodDeeds") || defaults.bool(forKey: "openNursery") {
                DebugLaunch.prepareBaby(BabyStore.profile(in: modelContext), in: modelContext)
            }
            if defaults.bool(forKey: "openGoodDeeds") {
                tab = .deeds
            } else if defaults.bool(forKey: "openNursery") {
                tab = .baby
            }
            #endif
        }
    }
}

#if DEBUG
/// Debug-only launch arguments for screenshots (MAC_BUILD.md). Launch arguments land in UserDefaults.
enum DebugLaunch {
    /// `-babyName Bean` names an unnamed baby (skips the naming sheet); `-babyMonths 8` sets the age.
    @MainActor
    static func prepareBaby(_ profile: BabyProfile, in context: ModelContext) {
        let defaults = UserDefaults.standard
        if profile.name.isEmpty, let name = defaults.string(forKey: "babyName"), !name.isEmpty {
            profile.name = name
            try? context.save()
        }
        let months = defaults.integer(forKey: "babyMonths")
        if months > 0, profile.state.months != months {
            profile.update { $0.setAgeForTesting(months: months) }
            try? context.save()
        }
    }
}
#endif

#Preview {
    RootTabView()
        .environment(LevelManager())
        .modelContainer(for: [LevelProgress.self, BabyProfile.self], inMemory: true)
}
