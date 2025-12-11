import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
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
                        
                        SecureField("", text: $password)
                            .textFieldStyle(DumpTextFieldStyle())
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { signIn() }
                    }
                }
                .padding(.horizontal, Theme.spacingLG)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacingLG)
                }
                
                // Sign in button
                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Signing in…" : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isFormValid && !isLoading))
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, Theme.spacingLG)
                .padding(.top, Theme.spacingSM)
                
                Spacer()
                Spacer()
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func signIn() {
        guard isFormValid else { return }
        
        focusedField = nil
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.signIn(email: email, password: password)
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

#Preview {
    AuthView()
        .environmentObject(AppState())
}
