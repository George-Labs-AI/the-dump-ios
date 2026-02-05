import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSignUpMode = false
    @State private var showForgotPassword = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: Theme.spacingLG) {
                Spacer()

                // Logo / Title
                VStack(spacing: Theme.spacingSM) {
                    Text("The Dump")
                        .font(.system(size: Theme.fontSizeXXL, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text("Quick capture for your thoughts")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.bottom, Theme.spacingXL)

                // Form
                VStack(spacing: Theme.spacingMD) {
                    // Email field
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Email")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)

                        TextField("", text: $email)
                            .textFieldStyle(DumpTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Password")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)

                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("", text: $password)
                                        .textContentType(isSignUpMode ? .newPassword : .password)
                                } else {
                                    SecureField("", text: $password)
                                        .textContentType(isSignUpMode ? .newPassword : .password)
                                }
                            }
                            .textFieldStyle(DumpPasswordFieldStyle())
                            .focused($focusedField, equals: .password)
                            .submitLabel(isSignUpMode ? .next : .go)
                            .onSubmit {
                                if isSignUpMode {
                                    focusedField = .confirmPassword
                                } else {
                                    submit()
                                }
                            }
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.trailing, Theme.spacingMD)
                        }
                    }

                    // Confirm password field (sign up only)
                    if isSignUpMode {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text("Confirm Password")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)

                            ZStack(alignment: .trailing) {
                                Group {
                                    if showConfirmPassword {
                                        TextField("", text: $confirmPassword)
                                            .textContentType(.newPassword)
                                    } else {
                                        SecureField("", text: $confirmPassword)
                                            .textContentType(.newPassword)
                                    }
                                }
                                .textFieldStyle(DumpPasswordFieldStyle())
                                .focused($focusedField, equals: .confirmPassword)
                                .submitLabel(.go)
                                .onSubmit { submit() }
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.trailing, Theme.spacingMD)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingLG)

                // Forgot password link (sign in only)
                if !isSignUpMode {
                    Button(action: { showForgotPassword = true }) {
                        Text("Forgot Password?")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacingLG)
                }

                // Submit button
                Button(action: submit) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                                .scaleEffect(0.8)
                        }
                        Text(submitButtonText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isFormValid && !isLoading))
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, Theme.spacingLG)
                .padding(.top, Theme.spacingSM)

                // Toggle between sign in / sign up
                Button(action: toggleMode) {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, Theme.spacingSM)

                Spacer()
                Spacer()
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private var submitButtonText: String {
        if isLoading {
            return isSignUpMode ? "Creating Account…" : "Signing In…"
        }
        return isSignUpMode ? "Create Account" : "Sign In"
    }

    private var isFormValid: Bool {
        let baseValid = !email.isEmpty && !password.isEmpty && email.contains("@")
        if isSignUpMode {
            return baseValid && !confirmPassword.isEmpty && password == confirmPassword
        }
        return baseValid
    }

    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSignUpMode.toggle()
            errorMessage = nil
            confirmPassword = ""
            showPassword = false
            showConfirmPassword = false
        }
    }

    private func submit() {
        guard isFormValid else { return }

        focusedField = nil
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUpMode {
                    try await AuthService.shared.signUp(email: email, password: password)
                } else {
                    try await AuthService.shared.signIn(email: email, password: password)
                }
                // AppState will automatically update via auth listener
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.spacingLG) {
                    if isSuccess {
                        // Success state
                        VStack(spacing: Theme.spacingMD) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.accent)

                            Text("Check Your Email")
                                .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            Text("We've sent password reset instructions to \(email)")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.spacingLG)
                        }
                        .padding(.top, Theme.spacingXL)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Text("Back to Sign In")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: true))
                        .padding(.horizontal, Theme.spacingLG)
                        .padding(.bottom, Theme.spacingXL)
                    } else {
                        // Input state
                        VStack(spacing: Theme.spacingMD) {
                            Text("Enter your email address and we'll send you instructions to reset your password.")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.spacingLG)

                            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                Text("Email")
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textSecondary)

                                TextField("", text: $email)
                                    .textFieldStyle(DumpTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, Theme.spacingLG)
                        }
                        .padding(.top, Theme.spacingLG)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.spacingLG)
                        }

                        Button(action: sendResetEmail) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Sending…" : "Send Reset Email")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: isEmailValid && !isLoading))
                        .disabled(!isEmailValid || isLoading)
                        .padding(.horizontal, Theme.spacingLG)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    private func sendResetEmail() {
        guard isEmailValid else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthService.shared.sendPasswordReset(email: email)
                isSuccess = true
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct DumpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Theme.spacingMD)
            .background(Theme.darkGray)
            .foregroundColor(Theme.textPrimary)
            .cornerRadius(Theme.cornerRadiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(Theme.lightGray, lineWidth: 1)
            )
    }
}

struct DumpPasswordFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.leading, Theme.spacingMD)
            .padding(.vertical, Theme.spacingMD)
            .padding(.trailing, Theme.spacingXL + 12) // Extra space for eye icon
            .background(Theme.darkGray)
            .foregroundColor(Theme.textPrimary)
            .cornerRadius(Theme.cornerRadiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(Theme.lightGray, lineWidth: 1)
            )
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
