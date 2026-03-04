//
//  LoginView.swift
//  DoomsDayChat
//
//  Created by Adib Anwar on 5/3/26.
//


import SwiftUI

struct LoginView: View {
    var onLoggedIn: (String) -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var errorText: String? = nil
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Oporajita Chat").font(.largeTitle).bold()

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorText = errorText {
                Text(errorText).foregroundColor(.red)
            }

            Button(isLoading ? "Logging in..." : "Login") {
                Task { await login() }
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty)
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    func login() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://chat.oporajita.win/api/login") else {
            errorText = "Bad URL"
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["username": username, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                errorText = msg ?? "Login failed"
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let token = json?["token"] as? String {
                onLoggedIn(token)
            } else {
                errorText = "Missing token"
            }
        } catch {
            errorText = "Network error: \(error.localizedDescription)"
        }
    }
}