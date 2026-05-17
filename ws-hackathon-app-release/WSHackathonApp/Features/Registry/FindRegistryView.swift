import SwiftUI

// MARK: - Find Registry View
struct FindRegistryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var registryId = ""
    @State private var hasSearched = false
    @State private var results: [Registry] = []

    // Password gate state
    @State private var pendingRegistry: Registry? = nil
    @State private var showPasswordSheet = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Custom nav bar ──────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    Spacer()
                    Text("FIND A REGISTRY")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)

                Rectangle().fill(Color(white: 0.9)).frame(height: 1)

                // ── Form + results ──────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header copy
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISCOVER")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(Color(white: 0.5))
                            Text("Find a Registry")
                                .font(.system(size: 30, weight: .light))
                                .foregroundColor(.black)
                            Text("Search by name or paste a registry ID.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.5))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                        // ── Form fields ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 24) {
                            fieldRow(label: "FIRST NAME", placeholder: "e.g. Priya", text: $firstName)
                            fieldRow(label: "LAST NAME",  placeholder: "e.g. Sharma", text: $lastName)

                            HStack {
                                Rectangle().fill(Color(white: 0.9)).frame(height: 1)
                                Text("OR")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                                    .padding(.horizontal, 8)
                                Rectangle().fill(Color(white: 0.9)).frame(height: 1)
                            }

                            fieldRow(label: "REGISTRY ID", placeholder: "Paste registry ID", text: $registryId)
                        }
                        .padding(.horizontal, 20)

                        // ── Results ─────────────────────────────────────────
                        if hasSearched {
                            VStack(alignment: .leading, spacing: 12) {
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 32)

                                HStack {
                                    Text("SEARCH RESULTS")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(1.5)
                                        .foregroundColor(Color(white: 0.5))
                                    Spacer()
                                    Text("\(results.count) found")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.5))
                                }

                                if results.isEmpty {
                                    noResultsView
                                } else {
                                    ForEach(results) { reg in
                                        registryResultCard(reg)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }

                // ── Search button ───────────────────────────────────────────
                Button {
                    runSearch()
                } label: {
                    Text("SEARCH REGISTRY")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canSearch ? Color.black : Color(white: 0.85))
                }
                .disabled(!canSearch)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPasswordSheet) {
            if let reg = pendingRegistry {
                PasswordGateSheet(registry: reg) { success in
                    showPasswordSheet = false
                    if success {
                        tabBarVM.registryPath.append(.registryDetail(reg.id))
                    }
                }
                .environmentObject(registryRepo)
            }
        }
    }

    // MARK: - Helpers

    private var canSearch: Bool {
        !firstName.isEmpty || !lastName.isEmpty || !registryId.isEmpty
    }

    private func runSearch() {
        results = registryRepo.search(
            firstName: firstName,
            lastName: lastName,
            registryId: registryId
        )
        hasSearched = true
    }

    @ViewBuilder
    private func fieldRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(Color(white: 0.5))
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .autocorrectionDisabled()
            Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.top, 4)
        }
    }

    @ViewBuilder
    private func registryResultCard(_ reg: Registry) -> some View {
        Button {
            handleTap(on: reg)
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(white: 0.96))
                        .frame(width: 44, height: 44)
                    Image(systemName: eventIcon(reg.event))
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(reg.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                    Text(reg.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                }

                Spacer()

                // Visibility badge
                visibilityBadge(reg.visibility)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            }
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(Color(white: 0.75))
                .padding(.top, 24)
            Text("No registry found")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
            Text("Try a different name or check the registry ID.")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func visibilityBadge(_ v: RegistryVisibility) -> some View {
        HStack(spacing: 4) {
            Image(systemName: v == .protected ? "lock.fill" : v == .private ? "eye.slash" : "globe")
                .font(.system(size: 10))
            Text(v.title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(v == .protected ? Color(red: 0.5, green: 0.3, blue: 0) : Color(white: 0.4))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(v == .protected ? Color(red: 1, green: 0.95, blue: 0.85) : Color(white: 0.95))
        .cornerRadius(4)
    }

    private func eventIcon(_ event: RegistryEvent) -> String {
        switch event {
        case .wedding:      return "heart"
        case .anniversary:  return "sparkles"
        case .housewarming: return "house"
        case .birthday:     return "gift"
        }
    }

    private func handleTap(on reg: Registry) {
        // If owner – go directly
        if registryRepo.isOwner(registryId: reg.id) {
            tabBarVM.registryPath.append(.registryDetail(reg.id))
            return
        }
        // Private – no access
        if reg.visibility == .private { return }
        // Protected – show password sheet
        if reg.visibility == .protected {
            pendingRegistry = reg
            showPasswordSheet = true
            return
        }
        // Public – go in
        tabBarVM.registryPath.append(.registryDetail(reg.id))
    }
}

// MARK: - Password Gate Sheet
struct PasswordGateSheet: View {
    let registry: Registry
    let onResult: (Bool) -> Void

    @EnvironmentObject var registryRepo: RegistryRepository
    @State private var enteredPassword = ""
    @State private var failed = false
    @State private var shaking = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color(white: 0.85))
                    .frame(width: 36, height: 4)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("PROTECTED REGISTRY")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.5))
                    Text(registry.displayName)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.black)
                    Text("This registry is password protected.\nEnter the password to become a collaborator.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PASSWORD")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.5))

                    SecureField("Enter registry password", text: $enteredPassword)
                        .font(.system(size: 16))
                        .foregroundColor(.black)

                    Rectangle()
                        .fill(failed ? Color.red.opacity(0.5) : Color(white: 0.9))
                        .frame(height: 1)
                        .padding(.top, 4)
                        .animation(.easeInOut, value: failed)

                    if failed {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Incorrect password. Please try again.")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .offset(x: shaking ? -8 : 0)
                .animation(shaking ? .default.repeatCount(4, autoreverses: true).speed(8) : .default, value: shaking)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        attemptJoin()
                    } label: {
                        Text("JOIN REGISTRY")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(!enteredPassword.isEmpty ? Color.black : Color(white: 0.85))
                    }
                    .disabled(enteredPassword.isEmpty)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Button("Cancel") { onResult(false) }
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                        .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.hidden)
    }

    private func attemptJoin() {
        let success = registryRepo.joinRegistry(id: registry.id, password: enteredPassword)
        if success {
            onResult(true)
        } else {
            failed = true
            shaking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shaking = false
            }
            enteredPassword = ""
        }
    }
}
