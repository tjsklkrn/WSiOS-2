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
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Account Header
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(white: 0.95))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "person")
                                        .font(.system(size: 26, weight: .ultraLight))
                                        .foregroundColor(Color(white: 0.4))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Guest User")
                                        .font(.system(size: 18, weight: .light))
                                        .foregroundColor(.black)
                                    Text("guest@example.com")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)

                            Rectangle()
                                .fill(Color(white: 0.88))
                                .frame(height: 1)
                        }

                        // MARK: - Menu Sections
                        WSProfileSection(title: "ACCOUNT") {
                            WSProfileRow(title: "Edit Profile", icon: "pencil") {
                                showEditProfile = true
                            }
                            WSProfileRow(title: "Order History", icon: "clock.arrow.circlepath") {
                                showOrderHistory = true
                            }
                            WSProfileRow(title: "Track My Order", icon: "shippingbox") {
                                showTrackOrder = true
                            }
                        }

                        WSProfileSection(title: "PREFERENCES") {
                            WSProfileRow(title: "Email Preferences", icon: "envelope") {}
                            WSProfileRow(title: "Notifications", icon: "bell") {}
                            WSProfileRow(title: "Address Book", icon: "map") {}
                        }

                        WSProfileSection(title: "SUPPORT") {
                            WSProfileRow(title: "Help & FAQ", icon: "questionmark.circle") {}
                            WSProfileRow(title: "Contact Us", icon: "message") {}
                        }

                        // MARK: - Sign Out
                        Button {
                            showSignOutAlert = true
                        } label: {
                            HStack {
                                Text("SIGN OUT")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(1.2)
                                    .foregroundColor(Color(red: 0.64, green: 0.07, blue: 0.07))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color(white: 0.88))
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        // Brand mark at bottom
                        Text("Williams-Sonoma")
                            .font(.system(size: 11, weight: .light))
                            .tracking(1.5)
                            .foregroundColor(Color(white: 0.7))
                            .padding(.top, 36)
                            .padding(.bottom, 48)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) { EditProfileView() }
            .sheet(isPresented: $showOrderHistory) { OrderHistoryView() }
            .sheet(isPresented: $showTrackOrder) { TrackOrderView() }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {}
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - WS Profile Section

private struct WSProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 10)

            content()

            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - WS Profile Row

private struct WSProfileRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(.black)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(Color.white)

        Rectangle()
            .fill(Color(white: 0.93))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

// MARK: - Sub-screens

private struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = "Guest User"
    @State private var email = "guest@example.com"
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    WSFormField(label: "NAME", value: $name)
                    Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 16)
                    WSFormField(label: "EMAIL", value: $email)
                    Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 16)
                    WSFormField(label: "PHONE", value: $phone)
                    Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 16)
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("SAVE CHANGES")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.black)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                        .font(.system(size: 13))
                }
            }
        }
    }
}

private struct WSFormField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.3)
                .foregroundColor(Color(white: 0.5))
            TextField("", text: $value)
                .font(.system(size: 14))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct OrderHistoryView: View {
    @Environment(\.dismiss) var dismiss
    private let orders = [
        ("ORD-20250410", "Apr 10, 2025", "$129.95", "Delivered"),
        ("ORD-20250318", "Mar 18, 2025", "$249.00", "Delivered"),
        ("ORD-20250201", "Feb 01, 2025", "$89.95",  "Delivered")
    ]
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    ForEach(Array(orders.enumerated()), id: \.element.0) { index, order in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(order.0)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                Text(order.2)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            HStack {
                                Text(order.1)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.5))
                                Spacer()
                                Text(order.3.uppercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundColor(Color(red: 0.1, green: 0.5, blue: 0.2))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        Rectangle()
                            .fill(Color(white: 0.9))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Order History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.black)
                        .font(.system(size: 13))
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
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    Image(systemName: "shippingbox")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(Color(white: 0.7))
                        .padding(.bottom, 20)

                    Text("TRACK YOUR ORDER")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.black)
                        .padding(.bottom, 8)

                    Text("Enter your order number or tracking ID\nto get live updates.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ORDER / TRACKING NUMBER")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.3)
                            .foregroundColor(Color(white: 0.5))
                        TextField("", text: $trackingNumber)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .overlay(
                                Rectangle().stroke(Color(white: 0.82), lineWidth: 1)
                                    .padding(.top, 20)
                            )
                    }
                    .padding(.horizontal, 24)

                    Button {
                        // track action
                    } label: {
                        Text("TRACK ORDER")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.black)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .navigationTitle("Track Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.black)
                        .font(.system(size: 13))
                }
            }
        }
    }
}
