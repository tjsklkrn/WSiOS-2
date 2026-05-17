//
//  ProfileView.swift
//  WSHackathonApp
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileRepo: ProfileRepository
    @EnvironmentObject var authVM: AuthViewModel

    @State private var showEditProfile = false
    @State private var showOrderHistory = false
    @State private var showTrackOrder = false
    @State private var showSignOutAlert = false

    private var displayName: String {
        if let name = profileRepo.currentProfile?.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        if let name = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        if let email = Auth.auth().currentUser?.email,
           let username = email.split(separator: "@").first,
           !username.isEmpty {
            return String(username)
        }

        return "User"
    }

    private var accountDetail: String {
        if let phone = profileRepo.currentProfile?.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
           !phone.isEmpty {
            return phone
        }

        return Auth.auth().currentUser?.email ?? authVM.email
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Account Header
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.headline)
                            Text(accountDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Actions
                Section {
                    ProfileRow(icon: "pencil", title: "Edit Profile") {
                        showEditProfile = true
                    }
                    ProfileRow(icon: "clock.arrow.circlepath", title: "Order History") {
                        showOrderHistory = true
                    }
                    ProfileRow(icon: "shippingbox", title: "Track My Order") {
                        showTrackOrder = true
                    }
                }

                // MARK: - Sign Out
                Section {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.backward.square")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            // Edit Profile sheet
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(profileRepo)
                    .environmentObject(authVM)
            }
            // Order History sheet
            .sheet(isPresented: $showOrderHistory) {
                OrderHistoryView()
            }
            // Track Order sheet
            .sheet(isPresented: $showTrackOrder) {
                TrackOrderView()
            }
            // Sign out confirmation
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) { authVM.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Reusable row

private struct ProfileRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(.primary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sub-screens (placeholder stubs)

private struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileRepo: ProfileRepository
    @EnvironmentObject var authVM: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Full Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        TextField("Email", text: $email)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                            .keyboardType(.emailAddress)
                            .disabled(true) // Firebase auth email shouldn't be edited here
                    }
                    HStack {
                        Text("Phone")
                        Spacer()
                        TextField("Phone Number", text: $phone)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                            .keyboardType(.phonePad)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var profile = profileRepo.currentProfile ?? UserProfile(
                            fullName: "",
                            phoneNumber: "",
                            dateOfBirth: "",
                            gender: "",
                            address: ""
                        )
                        profile.fullName = name
                        profile.phoneNumber = phone
                        profileRepo.saveProfile(profile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = profileRepo.currentProfile?.fullName
                    ?? Auth.auth().currentUser?.displayName
                    ?? ""
                email = Auth.auth().currentUser?.email ?? authVM.email
                phone = profileRepo.currentProfile?.phoneNumber ?? ""
            }
        }
    }
}

private struct OrderHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var orders: [OrderHistoryItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                if orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color(.systemGray3))
                            .padding(.bottom, 8)

                        Text("No Orders Yet")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)

                        Text("You haven't placed any orders yet. Go explore our catalog and find something you love!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button(action: {
                            dismiss()
                        }) {
                            Text("EXPLORE CATALOG")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#C11F1F")) // Signature Red
                                .cornerRadius(4)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    List {
                        ForEach(orders) { order in
                            VStack(alignment: .leading, spacing: 12) {
                                // Order Header
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(order.id)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                        Text(order.dateString)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    
                                    // Status Badge
                                    Text(order.status.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(order.status == "Delivered" ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                                        .foregroundColor(order.status == "Delivered" ? .green : .orange)
                                        .cornerRadius(2)
                                }
                                
                                Divider()

                                // Order Items
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(order.items) { item in
                                        HStack(spacing: 10) {
                                            // Compact image preview block
                                            ZStack {
                                                Color(.systemGray5)
                                                Image(systemName: "photo")
                                                    .font(.caption)
                                                    .foregroundColor(Color(.systemGray3))
                                            }
                                            .frame(width: 36, height: 36)
                                            .cornerRadius(4)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.black)
                                                    .lineLimit(1)
                                                Text("\(item.quantity)x • \(item.price.formatted(.currency(code: "USD")))")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }

                                Divider()

                                // Order Total
                                HStack {
                                    Text("Total Price")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Text(order.total.formatted(.currency(code: "USD")))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#C11F1F")) // Signature Red Total
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.white)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Order History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .onAppear {
                orders = OrderHistoryManager.shared.getOrders()
            }
        }
    }
}

private struct TrackOrderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var trackingNumber = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
                Text("Track Your Order")
                    .font(.title2).fontWeight(.semibold)
                Text("Enter your order number or tracking ID to get live updates.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("Order / Tracking Number", text: $trackingNumber)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                Button {
                    // track action
                } label: {
                    Text("Track Order")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .navigationTitle("Track Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
