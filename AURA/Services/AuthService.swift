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
            session = try await client.auth.session
        } catch {
            session = nil
        }
        isLoading = false
    }

    func signInAnonymously() async throws {
        let response = try await client.auth.signInAnonymously()
        session = response.session
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }
}
