//
//  ChatViewModel.swift
//  DoomsDayChat
//
//  Created by Adib Anwar on 5/3/26.
//

import Foundation
import Combine
import SocketIO

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var connected: Bool = false

    private var manager: SocketManager?
    private var socket: SocketIOClient?

    func connect(token: String) {
        // Important: Socket.IO expects the *base* URL, not /socket.io
        guard let url = URL(string: "https://chat.oporajita.win") else { return }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .extraHeaders(["Origin": "https://chat.oporajita.win"])
        ])

        guard let manager else { return }
        socket = manager.defaultSocket

        // Provide JWT for handshake auth
        socket?.connect(withPayload: ["token": token])

        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.connected = true }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.connected = false }
        }

        socket?.on("chat:new") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            let msg = ChatMessage.from(dict: dict)
            Task { @MainActor in self?.messages.append(msg) }
        }

        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        connected = false
    }

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        socket?.emitWithAck("chat:send", trimmed).timingOut(after: 5) { _ in
            // optional: handle ack response
        }
    }
}

struct ChatMessage: Identifiable {
    let id: Int
    let username: String
    let text: String
    let createdAt: String

    static func from(dict: [String: Any]) -> ChatMessage {
        let id = dict["id"] as? Int ?? Int.random(in: 1...999999)
        let username = dict["username"] as? String ?? "unknown"
        let text = dict["text"] as? String ?? ""
        let createdAt = dict["created_at"] as? String ?? ""
        return ChatMessage(id: id, username: username, text: text, createdAt: createdAt)
    }
}
