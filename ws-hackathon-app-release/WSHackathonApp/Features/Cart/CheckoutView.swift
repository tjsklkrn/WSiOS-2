//
//  CheckoutView.swift
//  WSHackathonApp
//
//  Created by Harshwardhan Patil on 17/05/26.
//

import SwiftUI

struct CheckoutView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cartViewModel: CartViewModel
    let cartRepository: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    // MARK: - Step Wizard State
    @State private var currentStep = 1 // 1: Shipping, 2: Delivery, 3: Payment, 4: Review, 5: Success
    @State private var isLoadingCheckout = false
    @State private var showValidationErrors = false // Triggers visual error styling on invalid attempt

    // MARK: - Step 1: Shipping Form (Empty by default)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var address1 = ""
    @State private var address2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var phone = ""

    // MARK: - Step 2: Delivery Method
    @State private var selectedDeliveryOption = DeliveryOption.standard

    // MARK: - Step 3: Payment Method
    @State private var selectedPaymentMethod = PaymentMethod.creditCard
    @State private var cardNumber = ""
    @State private var expDate = ""
    @State private var cvv = ""
    @State private var nameOnCard = ""

    // MARK: - Format Validation Helpers

    private var isShippingFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        state.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
        zipCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 &&
        phone.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    private var isPaymentFormValid: Bool {
        if selectedPaymentMethod == .creditCard {
            return cardNumber.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 &&
                   expDate.contains("/") && expDate.count == 5 &&
                   cvv.count >= 3 &&
                   !nameOnCard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Nav Bar
                headerNavBar

                if currentStep < 5 {
                    // Progress Indicator (Stepper)
                    StepperProgressView(currentStep: currentStep)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 0.5),
                            alignment: .bottom
                        )
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if currentStep == 1 {
                            shippingStepView
                        } else if currentStep == 2 {
                            deliveryStepView
                        } else if currentStep == 3 {
                            paymentStepView
                        } else if currentStep == 4 {
                            reviewStepView
                        } else if currentStep == 5 {
                            successStepView
                        }
                    }
                    .padding(16)
                }

                if currentStep < 5 {
                    // Sticky Bottom Action Button
                    bottomButtonView
                }
            }

            if isLoadingCheckout {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    // MARK: - Header Nav Bar

    private var headerNavBar: some View {
        HStack {
            if currentStep > 1 && currentStep < 5 {
                Button(action: {
                    withAnimation { currentStep -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                }
            } else if currentStep == 1 {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                }
            } else {
                Spacer().frame(width: 36)
            }

            Spacer()

            Text(currentStep == 5 ? "ORDER COMPLETED" : "CHECKOUT")
                .font(.system(size: 15, weight: .bold)) // Sans-Serif style matching screenshot
                .foregroundColor(.black)
                .tracking(1.5)

            Spacer()

            Spacer().frame(width: 36) // Balance back button
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Step 1: Shipping Address View

    private var shippingStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SHIPPING ADDRESS")
                .font(.system(size: 11, weight: .bold)) // Sans-Serif style matching screenshot
                .foregroundColor(.black)
                .tracking(1.0)

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    CheckoutTextField(
                        label: "First Name",
                        text: $firstName,
                        placeholder: "Tejas",
                        showError: showValidationErrors && firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Required"
                    )
                    CheckoutTextField(
                        label: "Last Name",
                        text: $lastName,
                        placeholder: "Kulkarni",
                        showError: showValidationErrors && lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Required"
                    )
                }

                CheckoutTextField(
                    label: "Address 1",
                    text: $address1,
                    placeholder: "3250 Van Ness Ave",
                    showError: showValidationErrors && address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    errorMessage: "Street address is required"
                )
                CheckoutTextField(
                    label: "Address 2 (Optional)",
                    text: $address2,
                    placeholder: "Apt, Suite, Unit"
                )

                HStack(spacing: 16) {
                    CheckoutTextField(
                        label: "City",
                        text: $city,
                        placeholder: "San Francisco",
                        showError: showValidationErrors && city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Required"
                    )
                    CheckoutTextField(
                        label: "State",
                        text: $state,
                        placeholder: "CA",
                        showError: showValidationErrors && state.trimmingCharacters(in: .whitespacesAndNewlines).count < 2,
                        errorMessage: "Enter 2 chars"
                    )
                }

                HStack(spacing: 16) {
                    CheckoutTextField(
                        label: "Zip Code",
                        text: $zipCode,
                        placeholder: "94109",
                        showError: showValidationErrors && zipCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 5,
                        errorMessage: "Must be 5+ digits"
                    )
                    CheckoutTextField(
                        label: "Phone",
                        text: $phone,
                        placeholder: "555-0198",
                        showError: showValidationErrors && phone.trimmingCharacters(in: .whitespacesAndNewlines).count < 10,
                        errorMessage: "Must be 10+ digits"
                    )
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.systemGray4), lineWidth: 0.7)
            )
        }
    }

    // MARK: - Step 2: Delivery Method View

    private var deliveryStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DELIVERY METHOD")
                .font(.system(size: 11, weight: .bold)) // Sans-Serif style matching screenshot
                .foregroundColor(.black)
                .tracking(1.0)

            VStack(spacing: 12) {
                ForEach(DeliveryOption.allOptions, id: \.id) { option in
                    DeliveryOptionRow(
                        option: option,
                        isSelected: selectedDeliveryOption.id == option.id,
                        onSelect: { selectedDeliveryOption = option }
                    )
                }
            }
        }
    }

    // MARK: - Step 3: Payment Information View

    private var paymentStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PAYMENT METHOD")
                .font(.system(size: 11, weight: .bold)) // Sans-Serif style matching screenshot
                .foregroundColor(.black)
                .tracking(1.0)

            VStack(spacing: 10) {
                PaymentMethodRow(
                    icon: "creditcard",
                    name: "Credit Card",
                    isSelected: selectedPaymentMethod == .creditCard,
                    onSelect: { selectedPaymentMethod = .creditCard }
                )

                PaymentMethodRow(
                    icon: "apple.logo",
                    name: "Apple Pay",
                    isSelected: selectedPaymentMethod == .applePay,
                    onSelect: { selectedPaymentMethod = .applePay }
                )

                PaymentMethodRow(
                    icon: "p.circle",
                    name: "PayPal",
                    isSelected: selectedPaymentMethod == .payPal,
                    onSelect: { selectedPaymentMethod = .payPal }
                )
            }

            if selectedPaymentMethod == .creditCard {
                VStack(alignment: .leading, spacing: 20) {
                    CheckoutTextField(
                        label: "Card Number",
                        text: $cardNumber,
                        placeholder: "•••• •••• •••• 4242",
                        showError: showValidationErrors && cardNumber.trimmingCharacters(in: .whitespacesAndNewlines).count < 12,
                        errorMessage: "Must be 12+ digits"
                    )

                    HStack(spacing: 16) {
                        CheckoutTextField(
                            label: "Exp Date",
                            text: $expDate,
                            placeholder: "12/28",
                            showError: showValidationErrors && (!expDate.contains("/") || expDate.count != 5),
                            errorMessage: "Use MM/YY"
                        )
                        CheckoutTextField(
                            label: "CVV",
                            text: $cvv,
                            placeholder: "123",
                            showError: showValidationErrors && cvv.count < 3,
                            errorMessage: "3+ digits"
                        )
                    }

                    CheckoutTextField(
                        label: "Name on Card",
                        text: $nameOnCard,
                        placeholder: "Jane Doe",
                        showError: showValidationErrors && nameOnCard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Cardholder name is required"
                    )
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(.systemGray4), lineWidth: 0.7)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Step 4: Order Review View

    private var reviewStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Shipping summary
            summarySection(title: "SHIPPING TO") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(firstName) \(lastName)")
                        .fontWeight(.bold)
                        .font(.system(size: 13))
                    Text(address1)
                    if !address2.isEmpty { Text(address2) }
                    Text("\(city), \(state) \(zipCode)")
                    Text("Phone: \(phone)")
                }
            }

            // Delivery summary
            summarySection(title: "DELIVERY METHOD") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedDeliveryOption.name)
                            .fontWeight(.bold)
                            .font(.system(size: 13))
                        Text(selectedDeliveryOption.timeframe)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "$%.2f", selectedDeliveryOption.price))
                        .fontWeight(.bold)
                }
            }

            // Payment summary
            summarySection(title: "PAYMENT METHOD") {
                HStack {
                    switch selectedPaymentMethod {
                    case .creditCard:
                        Image(systemName: "creditcard")
                            .foregroundColor(Color(hex: "#C11F1F"))
                        Text("Credit Card ending in \(cardNumber.suffix(4))")
                            .fontWeight(.bold)
                            .font(.system(size: 13))
                    case .applePay:
                        Image(systemName: "apple.logo")
                        Text("Apple Pay")
                            .fontWeight(.bold)
                            .font(.system(size: 13))
                    case .payPal:
                        Image(systemName: "p.circle")
                        Text("PayPal")
                            .fontWeight(.bold)
                            .font(.system(size: 13))
                    }
                }
            }

            // Price Summary
            summarySection(title: "ORDER TOTALS") {
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtotal")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cartViewModel.totalPriceText)
                    }

                    HStack {
                        Text("Shipping")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", selectedDeliveryOption.price))
                    }

                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Text("Grand Total")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        let grandTotal = cartViewModel.totalPrice + selectedDeliveryOption.price
                        Text(String(format: "$%.2f", grandTotal))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "#C11F1F")) // Highlight final total in brand red
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Order Success View

    private var successStepView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(Color(hex: "#C11F1F")) // Signature Red Completed emblem
                    .frame(width: 76, height: 76)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("ORDER PLACED SUCCESSFULLY")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .tracking(1.5)

                Text("Thank you for your purchase.\nYour order has been accepted and is being prepared.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            Spacer().frame(height: 10)

            Button(action: {
                dismiss()
                tabBarVM.selectTab(.home)
            }) {
                Text("CONTINUE SHOPPING")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#C11F1F")) // W-S Crimson Red Success CTA
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 440)
        .background(Color.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 0.7)
        )
    }

    // MARK: - Helper Views

    private func summarySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .tracking(1.0)

            VStack(alignment: .leading) {
                content()
            }
            .font(.system(size: 13))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.systemGray4), lineWidth: 0.7)
            )
        }
    }

    private var bottomButtonView: some View {
        VStack {
            Button(action: {
                if currentStep == 1 {
                    if isShippingFormValid {
                        withAnimation {
                            showValidationErrors = false
                            currentStep = 2
                        }
                    } else {
                        withAnimation {
                            showValidationErrors = true
                        }
                    }
                } else if currentStep == 2 {
                    withAnimation {
                        showValidationErrors = false
                        currentStep = 3
                    }
                } else if currentStep == 3 {
                    if isPaymentFormValid {
                        withAnimation {
                            showValidationErrors = false
                            currentStep = 4
                        }
                    } else {
                        withAnimation {
                            showValidationErrors = true
                        }
                    }
                } else if currentStep == 4 {
                    placeOrder()
                }
            }) {
                Text(currentStep == 4 ? "PLACE ORDER" : "CONTINUE")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#C11F1F")) // Signature Crimson Red
                    .cornerRadius(4) // Flat rectangular CTA style
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Checkout Action Trigger

    private func placeOrder() {
        isLoadingCheckout = true
        Task {
            await cartRepository.checkout()
            await cartViewModel.loadCart()
            isLoadingCheckout = false
            withAnimation {
                currentStep = 5
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Stepper Progress View Component (Flat, Editorial design)
// ---------------------------------------------------------------------------

private struct StepperProgressView: View {
    let currentStep: Int

    private let steps = ["Shipping", "Delivery", "Payment", "Review"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                let stepNum = index + 1
                let isActive = stepNum == currentStep
                let isCompleted = stepNum < currentStep

                // Step Circle & Label Node
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(isCompleted || isActive ? Color(hex: "#C11F1F") : Color(.systemGray4), lineWidth: 1.5)
                            .background(Circle().fill(isActive || isCompleted ? Color(hex: "#C11F1F") : Color.white))
                            .frame(width: 24, height: 24)

                        Text("\(stepNum)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isActive || isCompleted ? .white : Color(.systemGray4))
                    }

                    Text(steps[index])
                        .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                        .foregroundColor(isActive ? Color(hex: "#C11F1F") : Color(.systemGray4))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                // Connecting Line between steps (except after last step)
                if index < steps.count - 1 {
                    Spacer()
                    Rectangle()
                        .fill(stepNum < currentStep ? Color(hex: "#C11F1F") : Color(.systemGray4))
                        .frame(height: 1.5)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 20) // Align line visually with circles
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// ---------------------------------------------------------------------------
// Custom Text Field Component with Inline Validation Error Layout
// ---------------------------------------------------------------------------

private struct CheckoutTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var showError: Bool = false
    var errorMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(showError ? Color(hex: "#C11F1F") : Color(.systemGray2))
                    .tracking(0.5)

                Spacer()

                if showError && !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#C11F1F"))
                }
            }

            TextField(placeholder, text: $text)
                .font(.system(size: 13))
                .foregroundColor(.black)
                .autocorrectionDisabled()

            Rectangle()
                .fill(showError ? Color(hex: "#C11F1F") : Color(.systemGray4))
                .frame(height: 1)
        }
    }
}

// ---------------------------------------------------------------------------
// Custom Delivery Option Row Component (Flat rectangular rows with W-S signature red accents)
// ---------------------------------------------------------------------------

private struct DeliveryOptionRow: View {
    let option: DeliveryOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Radio icon
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#C11F1F") : Color(.systemGray4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#C11F1F"))
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                    Text(option.timeframe)
                        .font(.system(size: 11))
                        .foregroundColor(Color(.systemGray))
                }

                Spacer()

                Text(String(format: "$%.2f", option.price))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color(hex: "#C11F1F") : Color(.systemGray4), lineWidth: isSelected ? 1.5 : 0.7)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ---------------------------------------------------------------------------
// Custom Payment Method Row Component (Flat layout with Crimson Red highlights)
// ---------------------------------------------------------------------------

private struct PaymentMethodRow: View {
    let icon: String
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? Color(hex: "#C11F1F") : .black)
                    .frame(width: 24)

                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#C11F1F") : Color(.systemGray4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#C11F1F"))
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color(hex: "#C11F1F") : Color(.systemGray4), lineWidth: isSelected ? 1.5 : 0.7)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ---------------------------------------------------------------------------
// Structs & Enums Definitions
// ---------------------------------------------------------------------------

private struct DeliveryOption {
    let id: String
    let name: String
    let price: Double
    let timeframe: String

    static let standard = DeliveryOption(id: "std", name: "Standard Shipping", price: 15.00, timeframe: "5-7 Business Days")
    static let express = DeliveryOption(id: "exp", name: "Express Shipping", price: 25.00, timeframe: "2-3 Business Days")
    static let nextDay = DeliveryOption(id: "nxt", name: "Next Day Delivery", price: 45.00, timeframe: "1 Business Day")

    static let allOptions = [standard, express, nextDay]
}

private enum PaymentMethod {
    case creditCard
    case applePay
    case payPal
}
