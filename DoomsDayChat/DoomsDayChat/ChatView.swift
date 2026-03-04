//
//  ChatView.swift
//  DoomsDayChat
//
//  Created by Adib Anwar on 5/3/26.
//


import SwiftUI

struct ChatView: View {
    let token: String
    let onLogout: () -> Void

    @StateObject private var vm = ChatViewModel()
    @State private var input = ""

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(vm.connected ? .green : .red)
                Text(vm.connected ? "Connected" : "Disconnected")
                Spacer()
                Button("Logout") {
                    vm.disconnect()
                    onLogout()
                }
            }
            .padding(.horizontal)
            .padding(.top)

            List(vm.messages) { msg in
                VStack(alignment: .leading, spacing: 4) {
                    Text(msg.username).font(.headline)
                    Text(msg.text)
                }
            }

            HStack {
                TextField("Message...", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    vm.send(text: input)
                    input = ""
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            vm.connect(token: token)
        }
        .onDisappear {
            vm.disconnect()
        }
    }
}