//
//  RootView.swift
//  DoomsDayChat
//
//  Created by Adib Anwar on 5/3/26.
//


import SwiftUI

struct RootView: View {
    @State private var token: String? = nil

    var body: some View {
        if let token = token {
            ChatView(token: token) {
                self.token = nil
            }
        } else {
            LoginView { newToken in
                self.token = newToken
            }
        }
    }
}