// AURA/Services/AuthService.swift
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    let client: SupabaseClient

    @Published var session: Session?
    @Published var isLoading = true

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        Task { await refreshSession() }
    }

    func refreshSession() async {
        do {
            session = try await client.auth.refreshSession()
        } catch {
            // Refresh token also expired — force re-login
            session = nil
        }
        isLoading = false
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        session = try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
    }

    func sendEmailOTP(_ email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    func verifyEmailOTP(email: String, token: String) async throws {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
        session = response.session
    }

    func signInAnonymously() async throws {
        session = try await client.auth.signInAnonymously()
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }
}
