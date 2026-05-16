//
//  ProfileView.swift
//  WSHackathonApp
//

import SwiftUI

struct ProfileView: View {

    @State private var showEditProfile = false
    @State private var showOrderHistory = false
    @State private var showTrackOrder = false
    @State private var showSignOutAlert = false

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
                            Text("Guest User")
                                .font(.headline)
                            Text("guest@example.com")
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
            // Edit Profile sheet
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
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
                Button("Sign Out", role: .destructive) { /* sign out logic */ }
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
    @State private var name = "Guest User"
    @State private var email = "guest@example.com"
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
                    Button("Save") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct OrderHistoryView: View {
    @Environment(\.dismiss) var dismiss
    // Mocked orders
    private let orders = [
        ("ORD-20250410", "Apr 10, 2025", "$129.95", "Delivered"),
        ("ORD-20250318", "Mar 18, 2025", "$249.00", "Delivered"),
        ("ORD-20250201", "Feb 01, 2025", "$89.95",  "Delivered")
    ]
    var body: some View {
        NavigationStack {
            List(orders, id: \.0) { order in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(order.0).font(.subheadline).fontWeight(.semibold)
                        Spacer()
                        Text(order.2).font(.subheadline).foregroundColor(.primary)
                    }
                    HStack {
                        Text(order.1).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(order.3)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Order History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
