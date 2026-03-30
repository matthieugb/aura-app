# AURA — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** iOS app Swift natif permettant de prendre un selfie, choisir un background, et générer une photo relightée via IC-Light (+ animation Kling en premium).

**Architecture:** SwiftUI frontend → Supabase Edge Functions backend → Replicate (RMBG 2.0 + IC-Light) + Kling API. Auth, DB et storage via Supabase. Freemium géré par RevenueCat.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation, Supabase Swift SDK, RevenueCat SDK, URLSession pour les appels API.

**Design reference:** `docs/plans/2026-03-30-aura-design.md`
**Prototype UI:** `../aura-design.html`

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `AURA.xcodeproj`
- Create: `AURA/App/AURAApp.swift`
- Create: `AURA/App/ContentView.swift`
- Create: `Package.swift` (ou Swift Package Manager via Xcode)

**Step 1: Créer le projet Xcode**

Dans Xcode 15+ :
- File → New → Project → iOS → App
- Product Name: `AURA`
- Bundle ID: `com.yourname.aura`
- Interface: SwiftUI
- Language: Swift
- Cocher "Include Tests"

**Step 2: Ajouter les dépendances via Swift Package Manager**

Dans Xcode → File → Add Package Dependencies :

```
https://github.com/supabase/supabase-swift  — version ~2.0
https://github.com/RevenueCat/purchases-ios — version ~4.0
```

**Step 3: Vérifier le build**

`Cmd+B` — doit compiler sans erreur.

**Step 4: Commit**

```bash
git init
git add .
git commit -m "feat: initial Xcode project setup with Supabase + RevenueCat SPM deps"
```

---

## Task 2: Configuration & Constants

**Files:**
- Create: `AURA/Config/AppConfig.swift`
- Create: `AURA/Config/Secrets.xcconfig` (gitignored)

**Step 1: Créer AppConfig.swift**

```swift
// AURA/Config/AppConfig.swift
import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "")!
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    static let revenueCatAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? ""

    enum Entitlements {
        static let premium = "premium"
    }

    enum Credits {
        static let freePhotosPerDay = 5
        static let premiumAnimationsPerMonth = 20
    }
}
```

**Step 2: Ajouter Secrets.xcconfig**

Créer `Secrets.xcconfig` (ajouter au .gitignore) :
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
REVENUECAT_API_KEY = your-revenuecat-key
```

Dans Xcode → Project → Info → Configurations → Debug/Release → pointer sur `Secrets.xcconfig`.

**Step 3: Commit**

```bash
git add AURA/Config/AppConfig.swift
git commit -m "feat: app configuration and secrets setup"
```

---

## Task 3: Supabase — Schema & Auth

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`
- Create: `AURA/Services/AuthService.swift`

**Step 1: Créer le schema SQL**

Dans le dashboard Supabase → SQL Editor :

```sql
-- supabase/migrations/001_initial_schema.sql

-- Users credits table
create table public.user_credits (
  id uuid references auth.users primary key,
  free_photos_used_today int default 0,
  free_photos_reset_at date default current_date,
  animations_used_this_month int default 0,
  animations_reset_at date default date_trunc('month', current_date),
  is_premium boolean default false,
  created_at timestamptz default now()
);

-- Generations history
create table public.generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  background_id text not null,
  result_url text,
  animation_url text,
  status text default 'pending', -- pending | processing | done | error
  created_at timestamptz default now()
);

-- Backgrounds catalog
create table public.backgrounds (
  id text primary key,
  name text not null,
  category text not null, -- studio | nature | urban | luxury
  storage_path text not null,
  is_premium boolean default false,
  sort_order int default 0
);

-- RLS
alter table public.user_credits enable row level security;
alter table public.generations enable row level security;

create policy "Users can read own credits" on public.user_credits
  for select using (auth.uid() = id);

create policy "Users can read own generations" on public.generations
  for select using (auth.uid() = user_id);

create policy "Users can insert own generations" on public.generations
  for insert with check (auth.uid() = user_id);
```

**Step 2: Créer AuthService.swift**

```swift
// AURA/Services/AuthService.swift
import Foundation
import Supabase

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    var supabase: SupabaseClient { client }

    @Published var session: Session?
    @Published var isLoading = true

    private init() {
        Task { await refreshSession() }
    }

    func refreshSession() async {
        session = try? await client.auth.session
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
```

**Step 3: Commit**

```bash
git add supabase/ AURA/Services/AuthService.swift
git commit -m "feat: supabase schema and auth service"
```

---

## Task 4: Navigation & App Shell

**Files:**
- Create: `AURA/App/AURAApp.swift`
- Create: `AURA/Navigation/AppRouter.swift`
- Create: `AURA/Screens/SplashScreen.swift`

**Step 1: AppRouter.swift**

```swift
// AURA/Navigation/AppRouter.swift
import SwiftUI

enum AppRoute: Hashable {
    case camera
    case gallery
    case processing(GenerationRequest)
    case result(Generation)
}

struct GenerationRequest: Hashable {
    let selfieData: Data
    let backgroundID: String
}

@MainActor
class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func reset() { path = NavigationPath() }
}
```

**Step 2: AURAApp.swift**

```swift
// AURA/App/AURAApp.swift
import SwiftUI
import RevenueCat

@main
struct AURAApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var router = AppRouter()

    init() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            if auth.isLoading {
                SplashScreen()
            } else if auth.session == nil {
                SplashScreen(showOnboarding: true)
            } else {
                NavigationStack(path: $router.path) {
                    CameraScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .camera: CameraScreen()
                            case .gallery: GalleryScreen()
                            case .processing(let req): ProcessingScreen(request: req)
                            case .result(let gen): ResultScreen(generation: gen)
                            }
                        }
                }
                .environmentObject(router)
            }
        }
    }
}
```

**Step 3: SplashScreen.swift (design)**

```swift
// AURA/Screens/SplashScreen.swift
import SwiftUI

struct SplashScreen: View {
    var showOnboarding = false
    @StateObject private var auth = AuthService.shared

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            // Background gradient glow
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Light", size: 72))
                        .foregroundColor(.white)
                        .tracking(18)

                    Rectangle()
                        .fill(Color(hex: "C4894A"))
                        .frame(width: 40, height: 1)

                    Text("Step into the light.")
                        .font(.custom("CormorantGaramond-LightItalic", size: 18))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                }

                Spacer()

                if showOnboarding {
                    VStack(spacing: 16) {
                        Button("Get Started") {
                            Task { try? await auth.signInAnonymously() }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("I already have an account") {}
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}
```

**Step 4: Helpers — Color(hex:) et custom button style**

```swift
// AURA/Utils/ColorExtension.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// AURA/Utils/ButtonStyles.swift
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .tracking(3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(hex: "C4894A"))
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

**Step 5: Vérifier build + preview**

`Cmd+B`. Ouvrir preview de SplashScreen dans Xcode Canvas.

**Step 6: Commit**

```bash
git add AURA/
git commit -m "feat: app shell, router, splash screen"
```

---

## Task 5: Camera Screen

**Files:**
- Create: `AURA/Screens/CameraScreen.swift`
- Create: `AURA/Camera/CameraManager.swift`
- Create: `AURA/Camera/CameraPreviewView.swift`

**Step 1: CameraManager.swift**

```swift
// AURA/Camera/CameraManager.swift
import AVFoundation
import SwiftUI

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isAuthorized = false

    private let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .front

    var captureSession: AVCaptureSession { session }

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            isAuthorized = status == .authorized
        }
        if isAuthorized { setupSession() }
    }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        Task.detached { [weak self] in self?.session.startRunning() }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func flipCamera() {
        currentPosition = currentPosition == .front ? .back : .front
        session.inputs.forEach { session.removeInput($0) }
        setupSession()
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in self.capturedImage = image }
    }
}
```

**Step 2: CameraPreviewView.swift**

```swift
// AURA/Camera/CameraPreviewView.swift
import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
```

**Step 3: CameraScreen.swift**

```swift
// AURA/Screens/CameraScreen.swift
import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var bgStore = BackgroundStore.shared
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreviewView(session: camera.captureSession)
                .ignoresSafeArea()

            // Selected background preview (35% opacity)
            if let bg = bgStore.selected {
                Rectangle()
                    .fill(bg.previewGradient)
                    .ignoresSafeArea()
                    .opacity(0.35)
                    .animation(.easeInOut(duration: 0.4), value: bgStore.selected?.id)
            }

            // Frame guide
            OvalFrameGuide()

            // Top bar
            VStack {
                HStack {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Regular", size: 22))
                        .foregroundColor(.white)
                        .tracking(6)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 70)
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()
                CameraBottomBar(
                    onCapture: handleCapture,
                    onFlip: camera.flipCamera,
                    onSeeAll: { router.push(.gallery) }
                )
            }
        }
        .ignoresSafeArea()
        .task { await camera.requestPermission() }
        .onChange(of: camera.capturedImage) { image in
            guard let image = image,
                  let data = image.jpegData(compressionQuality: 0.85),
                  let bgID = bgStore.selected?.id else { return }
            router.push(.processing(GenerationRequest(selfieData: data, backgroundID: bgID)))
        }
    }

    private func handleCapture() {
        camera.capturePhoto()
    }
}

struct OvalFrameGuide: View {
    var body: some View {
        Ellipse()
            .stroke(Color(hex: "C4894A").opacity(0.4), lineWidth: 1)
            .frame(width: 240, height: 350)
    }
}
```

**Step 4: Commit**

```bash
git add AURA/Camera/ AURA/Screens/CameraScreen.swift
git commit -m "feat: camera screen with AVFoundation, background preview overlay"
```

---

## Task 6: Background Store & Gallery

**Files:**
- Create: `AURA/Models/Background.swift`
- Create: `AURA/Services/BackgroundStore.swift`
- Create: `AURA/Screens/GalleryScreen.swift`
- Create: `AURA/Components/CameraBottomBar.swift`

**Step 1: Background model**

```swift
// AURA/Models/Background.swift
import SwiftUI

struct Background: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: BackgroundCategory
    let storagePath: String
    let isPremium: Bool
    var imageURL: URL?

    enum BackgroundCategory: String, Codable, CaseIterable {
        case studio, nature, urban, luxury
        var label: String { rawValue.capitalized }
    }

    // Fallback gradient for preview when image not loaded
    var previewGradient: LinearGradient {
        switch id {
        case "golden-hour":
            return LinearGradient(colors: [Color(hex: "D4621A"), Color(hex: "F0953C"), Color(hex: "C4956A")], startPoint: .top, endPoint: .bottom)
        case "forest":
            return LinearGradient(colors: [Color(hex: "1A3A10"), Color(hex: "4A7A2A")], startPoint: .top, endPoint: .bottom)
        case "night-city":
            return LinearGradient(colors: [Color(hex: "060A18"), Color(hex: "1A2E58")], startPoint: .top, endPoint: .bottom)
        case "studio":
            return LinearGradient(colors: [Color(hex: "ECE8E4"), Color(hex: "D8D0C8")], startPoint: .top, endPoint: .bottom)
        case "beach":
            return LinearGradient(colors: [Color(hex: "FF7A50"), Color(hex: "FFE0A0"), Color(hex: "C4956A")], startPoint: .top, endPoint: .bottom)
        case "blue-hour":
            return LinearGradient(colors: [Color(hex: "1A2A5E"), Color(hex: "C4D4F0")], startPoint: .top, endPoint: .bottom)
        case "marble":
            return LinearGradient(colors: [Color(hex: "F0EDE8"), Color(hex: "DED6CC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "terracotta":
            return LinearGradient(colors: [Color(hex: "8B3A1A"), Color(hex: "E8C0A0")], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color(hex: "EAE0D2")], startPoint: .top, endPoint: .bottom)
        }
    }
}
```

**Step 2: BackgroundStore.swift**

```swift
// AURA/Services/BackgroundStore.swift
import Foundation
import Supabase

@MainActor
class BackgroundStore: ObservableObject {
    static let shared = BackgroundStore()

    @Published var backgrounds: [Background] = []
    @Published var selected: Background?
    @Published var isLoading = false

    private init() {
        // Load defaults immediately for offline/first-launch
        backgrounds = Self.defaultBackgrounds
        selected = backgrounds.first
        Task { await fetchFromSupabase() }
    }

    func fetchFromSupabase() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [Background] = try await AuthService.shared.supabase
                .from("backgrounds")
                .select()
                .order("sort_order")
                .execute()
                .value
            if !fetched.isEmpty { backgrounds = fetched }
        } catch {
            // Keep defaults on error
        }
    }

    func select(_ bg: Background) { selected = bg }

    static let defaultBackgrounds: [Background] = [
        Background(id: "golden-hour", name: "Golden Hour", category: .nature, storagePath: "backgrounds/golden-hour.jpg", isPremium: false),
        Background(id: "forest", name: "Forest", category: .nature, storagePath: "backgrounds/forest.jpg", isPremium: false),
        Background(id: "night-city", name: "Night City", category: .urban, storagePath: "backgrounds/night-city.jpg", isPremium: false),
        Background(id: "studio", name: "Studio", category: .studio, storagePath: "backgrounds/studio.jpg", isPremium: true),
        Background(id: "beach", name: "Sunset Beach", category: .nature, storagePath: "backgrounds/beach.jpg", isPremium: true),
        Background(id: "blue-hour", name: "Blue Hour", category: .urban, storagePath: "backgrounds/blue-hour.jpg", isPremium: true),
        Background(id: "marble", name: "Marble", category: .luxury, storagePath: "backgrounds/marble.jpg", isPremium: true),
        Background(id: "terracotta", name: "Terracotta", category: .luxury, storagePath: "backgrounds/terracotta.jpg", isPremium: true),
    ]
}
```

**Step 3: CameraBottomBar.swift**

```swift
// AURA/Components/CameraBottomBar.swift
import SwiftUI

struct CameraBottomBar: View {
    let onCapture: () -> Void
    let onFlip: () -> Void
    let onSeeAll: () -> Void

    @StateObject private var bgStore = BackgroundStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Strip header
            HStack {
                Text("BACKGROUND")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(4)
                    .foregroundColor(Color(hex: "9A8878"))
                Spacer()
                Button("See all →", action: onSeeAll)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "C4894A"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(bgStore.backgrounds) { bg in
                        BackgroundThumb(bg: bg, isSelected: bgStore.selected?.id == bg.id)
                            .onTapGesture { bgStore.select(bg) }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)

            // Capture row
            HStack(spacing: 48) {
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .light))
                        Text("Gallery")
                            .font(.system(size: 9))
                            .tracking(2)
                    }
                    .foregroundColor(Color.white.opacity(0.5))
                }

                Button(action: onCapture) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    }
                }

                Button(action: onFlip) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 22, weight: .light))
                        Text("Flip")
                            .font(.system(size: 9))
                            .tracking(2)
                    }
                    .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(hex: "0D0B09").opacity(0.95))
    }
}

struct BackgroundThumb: View {
    let bg: Background
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(bg.previewGradient)
                .frame(width: 60, height: 80)
                .cornerRadius(12)

            Text(bg.name)
                .font(.system(size: 8, weight: .medium))
                .tracking(1)
                .foregroundColor(.white)
                .padding(.bottom, 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "C4894A"), lineWidth: isSelected ? 2 : 0)
        )
    }
}
```

**Step 4: GalleryScreen.swift**

```swift
// AURA/Screens/GalleryScreen.swift
import SwiftUI

struct GalleryScreen: View {
    @StateObject private var bgStore = BackgroundStore.shared
    @EnvironmentObject private var router: AppRouter
    @State private var selectedCategory: Background.BackgroundCategory? = nil

    var filtered: [Background] {
        guard let cat = selectedCategory else { return bgStore.backgrounds }
        return bgStore.backgrounds.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                Text("Backgrounds")
                    .font(.custom("CormorantGaramond-Regular", size: 28))
                    .foregroundColor(Color(hex: "18120C"))

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryTab(label: "All", isActive: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(Background.BackgroundCategory.allCases, id: \.self) { cat in
                            CategoryTab(label: cat.label, isActive: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 20)
            .overlay(Divider(), alignment: .bottom)

            // Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, bg in
                        GalleryCard(bg: bg, isWide: idx == 0 && selectedCategory == nil)
                            .onTapGesture {
                                bgStore.select(bg)
                                router.pop()
                            }
                    }
                }
                .padding(16)
                .padding(.bottom, 100)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 10) {
                Button("← Back") { router.pop() }
                    .buttonStyle(OutlineButtonStyle())
                Button("Select") { router.pop() }
                    .buttonStyle(DarkButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(LinearGradient(colors: [.clear, Color(hex: "FDFAF7")], startPoint: .top, endPoint: .bottom))
        }
        .navigationBarHidden(true)
        .background(Color(hex: "FDFAF7"))
    }
}

struct CategoryTab: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .font(.system(size: 12))
            .foregroundColor(isActive ? .white : Color(hex: "9A8878"))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(isActive ? Color(hex: "18120C") : Color.clear)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "EAE0D2"), lineWidth: isActive ? 0 : 1))
    }
}

struct GalleryCard: View {
    let bg: Background
    let isWide: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(bg.previewGradient)
                .aspectRatio(isWide ? 16/9 : 3/4, contentMode: .fill)
                .cornerRadius(16)
                .gridCellColumns(isWide ? 2 : 1)

            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                .cornerRadius(16)

            HStack(alignment: .bottom) {
                Text(bg.name)
                    .font(.custom("CormorantGaramond-Regular", size: 16))
                    .foregroundColor(.white)
                Spacer()
                Text(bg.isPremium ? "★ Premium" : "Free")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(bg.isPremium ? Color(hex: "E8C084") : .white.opacity(0.5))
            }
            .padding(14)
        }
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "18120C"))
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "EAE0D2")))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .tracking(2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "18120C"))
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
```

**Step 5: Commit**

```bash
git add AURA/
git commit -m "feat: background store, gallery screen, camera bottom bar"
```

---

## Task 7: Supabase Edge Function — Generation Pipeline

**Files:**
- Create: `supabase/functions/generate/index.ts`

**Step 1: Créer la fonction Edge**

```typescript
// supabase/functions/generate/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const REPLICATE_API_TOKEN = Deno.env.get("REPLICATE_API_TOKEN")!
const KLING_API_KEY = Deno.env.get("KLING_API_KEY")!

async function replicateRun(model: string, input: Record<string, unknown>) {
  const res = await fetch("https://api.replicate.com/v1/models/" + model + "/predictions", {
    method: "POST",
    headers: {
      "Authorization": `Token ${REPLICATE_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ input }),
  })
  const prediction = await res.json()

  // Poll until done
  let result = prediction
  while (result.status !== "succeeded" && result.status !== "failed") {
    await new Promise(r => setTimeout(r, 1500))
    const poll = await fetch(result.urls.get, {
      headers: { "Authorization": `Token ${REPLICATE_API_TOKEN}` }
    })
    result = await poll.json()
  }
  if (result.status === "failed") throw new Error("Replicate failed: " + result.error)
  return result.output
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 })

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const authHeader = req.headers.get("Authorization")
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace("Bearer ", "") ?? "")
  if (!user) return new Response("Unauthorized", { status: 401 })

  const formData = await req.formData()
  const selfieFile = formData.get("selfie") as File
  const backgroundId = formData.get("backgroundId") as string
  const animate = formData.get("animate") === "true"

  // Fetch background URL from Supabase Storage
  const { data: bgData } = supabase.storage.from("backgrounds").getPublicUrl(`backgrounds/${backgroundId}.jpg`)
  const backgroundUrl = bgData.publicUrl

  // 1. Upload selfie to Supabase Storage
  const selfieBuffer = await selfieFile.arrayBuffer()
  const selfieKey = `selfies/${user.id}/${Date.now()}.jpg`
  await supabase.storage.from("generations").upload(selfieKey, selfieBuffer, { contentType: "image/jpeg" })
  const { data: { publicUrl: selfieUrl } } = supabase.storage.from("generations").getPublicUrl(selfieKey)

  // 2. RMBG 2.0 — background removal
  const rmbgOutput = await replicateRun("lucataco/bria-rmbg-2.0", {
    image: selfieUrl
  })
  const subjectUrl = Array.isArray(rmbgOutput) ? rmbgOutput[0] : rmbgOutput

  // 3. IC-Light — relighting conditioned on background
  const iclightOutput = await replicateRun("zsxkib/ic-light", {
    subject_image: subjectUrl,
    background_image: backgroundUrl,
    num_inference_steps: 25,
    guidance_scale: 1.5,
  })
  const relightedUrl = Array.isArray(iclightOutput) ? iclightOutput[0] : iclightOutput

  let animationUrl: string | null = null

  // 4. [Optional] Kling animation
  if (animate) {
    const klingRes = await fetch("https://api.klingai.com/v1/videos/image2video", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${KLING_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "kling-v1",
        image: relightedUrl,
        duration: "5",
        mode: "std",
        prompt: "subtle cinematic light movement, gentle atmosphere",
        cfg_scale: 0.5,
      })
    })
    const klingData = await klingRes.json()
    // Poll Kling job
    const jobId = klingData.data?.task_id
    if (jobId) {
      let klingResult = klingData
      while (klingResult.data?.task_status !== "succeed" && klingResult.data?.task_status !== "failed") {
        await new Promise(r => setTimeout(r, 3000))
        const poll = await fetch(`https://api.klingai.com/v1/videos/image2video/${jobId}`, {
          headers: { "Authorization": `Bearer ${KLING_API_KEY}` }
        })
        klingResult = await poll.json()
      }
      animationUrl = klingResult.data?.task_result?.videos?.[0]?.url ?? null
    }
  }

  // 5. Save generation to DB
  const { data: gen } = await supabase.from("generations").insert({
    user_id: user.id,
    background_id: backgroundId,
    result_url: relightedUrl,
    animation_url: animationUrl,
    status: "done",
  }).select().single()

  return new Response(JSON.stringify({
    generationId: gen.id,
    resultUrl: relightedUrl,
    animationUrl,
  }), {
    headers: { "Content-Type": "application/json" }
  })
})
```

**Step 2: Déployer**

```bash
# Installer Supabase CLI si besoin
brew install supabase/tap/supabase

supabase login
supabase link --project-ref your-project-ref

# Set secrets
supabase secrets set REPLICATE_API_TOKEN=r8_xxx
supabase secrets set KLING_API_KEY=xxx

supabase functions deploy generate
```

**Step 3: Tester via curl**

```bash
curl -X POST https://your-project.supabase.co/functions/v1/generate \
  -H "Authorization: Bearer YOUR_USER_JWT" \
  -F "selfie=@test-selfie.jpg" \
  -F "backgroundId=golden-hour" \
  -F "animate=false"
```

Réponse attendue : `{"generationId":"...", "resultUrl":"https://..."}` en ~15s.

**Step 4: Commit**

```bash
git add supabase/functions/
git commit -m "feat: supabase edge function — RMBG + IC-Light + Kling pipeline"
```

---

## Task 8: Generation Service (iOS)

**Files:**
- Create: `AURA/Services/GenerationService.swift`
- Create: `AURA/Models/Generation.swift`

**Step 1: Generation model**

```swift
// AURA/Models/Generation.swift
import Foundation

struct Generation: Identifiable, Codable {
    let id: String
    let backgroundId: String
    let resultUrl: String
    let animationUrl: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case backgroundId = "background_id"
        case resultUrl = "result_url"
        case animationUrl = "animation_url"
        case createdAt = "created_at"
    }
}

struct GenerationResponse: Codable {
    let generationId: String
    let resultUrl: String
    let animationUrl: String?
}
```

**Step 2: GenerationService.swift**

```swift
// AURA/Services/GenerationService.swift
import Foundation

@MainActor
class GenerationService: ObservableObject {
    static let shared = GenerationService()

    @Published var isGenerating = false
    @Published var progress: GenerationProgress = .idle

    enum GenerationProgress {
        case idle
        case removing
        case relighting
        case animating
        case done(GenerationResponse)
        case error(String)
    }

    func generate(selfieData: Data, backgroundID: String, animate: Bool = false) async throws -> GenerationResponse {
        isGenerating = true
        progress = .removing
        defer { isGenerating = false }

        guard let session = AuthService.shared.session else {
            throw GenerationError.notAuthenticated
        }

        let url = AppConfig.supabaseURL.appendingPathComponent("functions/v1/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendFormField(name: "backgroundId", value: backgroundID, boundary: boundary)
        body.appendFormField(name: "animate", value: animate ? "true" : "false", boundary: boundary)
        body.appendFileField(name: "selfie", filename: "selfie.jpg", data: selfieData, mimeType: "image/jpeg", boundary: boundary)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        progress = .relighting
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            progress = .error("Generation failed")
            throw GenerationError.serverError
        }

        let result = try JSONDecoder().decode(GenerationResponse.self, from: data)
        progress = .done(result)
        return result
    }
}

enum GenerationError: Error {
    case notAuthenticated
    case serverError
}

// Multipart helpers
extension Data {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    mutating func appendFileField(name: String, filename: String, data: Data, mimeType: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
```

**Step 3: Commit**

```bash
git add AURA/Services/GenerationService.swift AURA/Models/Generation.swift
git commit -m "feat: generation service with multipart upload to edge function"
```

---

## Task 9: Processing & Result Screens

**Files:**
- Create: `AURA/Screens/ProcessingScreen.swift`
- Create: `AURA/Screens/ResultScreen.swift`

**Step 1: ProcessingScreen.swift**

```swift
// AURA/Screens/ProcessingScreen.swift
import SwiftUI

struct ProcessingScreen: View {
    let request: GenerationRequest
    @StateObject private var genService = GenerationService.shared
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Floating preview
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(BackgroundStore.shared.selected?.previewGradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: 220, height: 280)

                    // Sweep animation
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Color(hex: "C4894A").opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 220, height: 280)
                        .cornerRadius(24)
                        .modifier(SweepAnimation())
                }
                .modifier(FloatAnimation())
                .padding(.bottom, 48)

                Text("Creating your light")
                    .font(.custom("CormorantGaramond-Light", size: 28))
                    .foregroundColor(.white)
                    .tracking(2)
                    .padding(.bottom, 8)

                Text("THIS TAKES ~15 SECONDS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(4)
                    .foregroundColor(Color(hex: "9A8878"))
                    .padding(.bottom, 48)

                // Steps
                VStack(spacing: 0) {
                    StepRow(label: "Removing background", state: stepState(for: 0))
                    StepRow(label: "Adapting light with IC-Light", state: stepState(for: 1))
                    StepRow(label: "Compositing final image", state: stepState(for: 2))
                }
                .padding(.horizontal, 40)
            }
        }
        .navigationBarHidden(true)
        .task { await runGeneration() }
    }

    private func stepState(for idx: Int) -> StepRow.State {
        switch genService.progress {
        case .removing: return idx == 0 ? .active : .pending
        case .relighting: return idx < 1 ? .done : (idx == 1 ? .active : .pending)
        case .animating: return idx < 2 ? .done : .active
        case .done: return .done
        default: return .pending
        }
    }

    private func runGeneration() async {
        do {
            let result = try await genService.generate(selfieData: request.selfieData, backgroundID: request.backgroundID)
            let gen = Generation(id: result.generationId, backgroundId: request.backgroundID,
                                 resultUrl: result.resultUrl, animationUrl: result.animationUrl,
                                 status: "done", createdAt: Date())
            router.push(.result(gen))
        } catch {
            router.pop()
        }
    }
}

struct StepRow: View {
    enum State { case pending, active, done }
    let label: String
    let state: State

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .overlay(state == .active ? Circle().stroke(Color(hex: "C4894A").opacity(0.3), lineWidth: 6) : nil)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: state == .active)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(labelColor)

            Spacer()
            if state == .done {
                Text("✓").font(.system(size: 12)).foregroundColor(Color(hex: "C4894A"))
            }
        }
        .padding(.vertical, 16)
        .overlay(Divider().background(Color.white.opacity(0.06)), alignment: .bottom)
    }

    var dotColor: Color {
        switch state {
        case .pending: return Color.white.opacity(0.15)
        case .active, .done: return Color(hex: "C4894A")
        }
    }

    var labelColor: Color {
        switch state {
        case .pending: return .white.opacity(0.4)
        case .active: return .white.opacity(0.9)
        case .done: return .white.opacity(0.8)
        }
    }
}

struct FloatAnimation: ViewModifier {
    @State private var up = false
    func body(content: Content) -> some View {
        content.offset(y: up ? -8 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever()) { up = true } }
    }
}

struct SweepAnimation: ViewModifier {
    @State private var offset: CGFloat = -220
    func body(content: Content) -> some View {
        content.offset(x: offset)
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { offset = 220 }
            }
    }
}
```

**Step 2: ResultScreen.swift**

```swift
// AURA/Screens/ResultScreen.swift
import SwiftUI

struct ResultScreen: View {
    let generation: Generation
    @EnvironmentObject private var router: AppRouter
    @StateObject private var genService = GenerationService.shared
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Result image
            ZStack(alignment: .top) {
                AsyncImage(url: URL(string: generation.resultUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(BackgroundStore.shared.selected?.previewGradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .clipped()

                // Top bar
                HStack {
                    Button { router.reset() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "E8C084")).frame(width: 6, height: 6)
                        Text("IC-Light · Relighted")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(Color(hex: "E8C084"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
            }

            // Bottom panel
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BackgroundStore.shared.selected?.name ?? "Background")
                            .font(.custom("CormorantGaramond-Regular", size: 20))
                            .foregroundColor(Color(hex: "18120C"))
                        Text("Warm ambient · Relighted")
                            .font(.system(size: 11))
                            .tracking(2)
                            .foregroundColor(Color(hex: "9A8878"))
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BackgroundStore.shared.selected?.previewGradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: 36, height: 36)
                }

                // Action buttons
                HStack(spacing: 10) {
                    ActionButton(icon: "arrow.down.circle", label: "Save") {
                        saveToPhotos()
                    }
                    ActionButton(icon: "square.and.arrow.up", label: "Share") {
                        shareImage()
                    }
                    AnimateButton(isLoading: isAnimating) {
                        Task { await animate() }
                    }
                }

                // Credits bar
                CreditsBar()
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .background(Color(hex: "FDFAF7"))
    }

    private func saveToPhotos() {
        // UIImageWriteToSavedPhotosAlbum implementation
    }

    private func shareImage() {
        guard let url = URL(string: generation.resultUrl) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .rootViewController?.present(av, animated: true)
    }

    private func animate() async {
        isAnimating = true
        defer { isAnimating = false }
        // Check premium, then re-call generate with animate=true
        // TODO: RevenueCat gate
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .light))
                Text(label).font(.system(size: 10, weight: .medium)).tracking(3)
            }
            .foregroundColor(Color(hex: "18120C"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "F7F3ED"))
            .cornerRadius(14)
        }
    }
}

struct AnimateButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if isLoading {
                    ProgressView().tint(Color(hex: "E8C084"))
                } else {
                    Image(systemName: "play.circle").font(.system(size: 20, weight: .light))
                }
                Text("Animate ✦").font(.system(size: 10, weight: .medium)).tracking(3)
            }
            .foregroundColor(Color(hex: "E8C084"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "18120C"))
            .cornerRadius(14)
        }
        .disabled(isLoading)
    }
}

struct CreditsBar: View {
    var body: some View {
        HStack {
            Text("**3** free photos remaining today")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "9A8878"))
            Spacer()
            Button("Upgrade →"){}
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "C4894A"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F7F3ED"))
        .cornerRadius(12)
    }
}
```

**Step 3: Commit**

```bash
git add AURA/Screens/
git commit -m "feat: processing and result screens"
```

---

## Task 10: RevenueCat — Freemium Gate

**Files:**
- Create: `AURA/Services/PurchaseService.swift`
- Create: `AURA/Screens/PaywallScreen.swift`

**Step 1: PurchaseService.swift**

```swift
// AURA/Services/PurchaseService.swift
import Foundation
import RevenueCat

@MainActor
class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    @Published var isPremium = false
    @Published var isLoading = false

    private init() {
        Task { await checkStatus() }
    }

    func checkStatus() async {
        let info = try? await Purchases.shared.customerInfo()
        isPremium = info?.entitlements[AppConfig.Entitlements.premium]?.isActive == true
    }

    func purchase() async throws {
        isLoading = true
        defer { isLoading = false }

        let offerings = try await Purchases.shared.offerings()
        guard let package = offerings.current?.availablePackages.first else { return }
        let (_, info, _) = try await Purchases.shared.purchase(package: package)
        isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
    }

    func restore() async throws {
        let info = try await Purchases.shared.restorePurchases()
        isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
    }
}
```

**Step 2: Gate the Animate button**

Dans `ResultScreen.swift`, modifier `animate()` :

```swift
private func animate() async {
    guard PurchaseService.shared.isPremium else {
        // Show paywall
        showPaywall = true
        return
    }
    isAnimating = true
    defer { isAnimating = false }
    _ = try? await genService.generate(
        selfieData: Data(), // re-use stored selfie
        backgroundID: generation.backgroundId,
        animate: true
    )
}
```

Ajouter `@State private var showPaywall = false` et `.sheet(isPresented: $showPaywall) { PaywallScreen() }`.

**Step 3: PaywallScreen.swift minimal**

```swift
// AURA/Screens/PaywallScreen.swift
import SwiftUI

struct PaywallScreen: View {
    @StateObject private var purchases = PurchaseService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Text("AURA Premium")
                .font(.custom("CormorantGaramond-Regular", size: 36))
                .tracking(4)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "play.circle", text: "20 Kling animations per month")
                FeatureRow(icon: "photo.stack", text: "Unlimited photo generations")
                FeatureRow(icon: "star", text: "Full background catalog")
            }

            Button("Subscribe · $14.99/month") {
                Task { try? await purchases.purchase() }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Restore purchases") { Task { try? await purchases.restore() } }
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "9A8878"))
        }
        .padding(32)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Color(hex: "C4894A"))
            Text(text).font(.system(size: 15))
        }
    }
}
```

**Step 4: Commit**

```bash
git add AURA/Services/PurchaseService.swift AURA/Screens/PaywallScreen.swift
git commit -m "feat: RevenueCat premium gate for Kling animations"
```

---

## Task 11: Polish & App Store Prep

**Step 1: Info.plist — permissions**

Ajouter dans `AURA/Info.plist` :
```xml
<key>NSCameraUsageDescription</key>
<string>AURA uses your camera to take your selfie.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>AURA saves your generated photos to your library.</string>
```

**Step 2: App icon & launch screen**

- Exporter le logo "AURA" en SVG depuis le prototype HTML
- Générer les tailles via [appicon.ai](https://appicon.ai)
- Ajouter dans `Assets.xcassets/AppIcon`

**Step 3: Crash reporting — Supabase logs**

Dans le dashboard Supabase → Edge Functions → Logs : vérifier que les appels passent sans erreur en prod.

**Step 4: TestFlight**

```bash
# Archive dans Xcode
Product → Archive → Distribute → App Store Connect
```

**Step 5: Commit final**

```bash
git add .
git commit -m "feat: polish, permissions, ready for TestFlight"
```

---

## Checklist de test manuel

- [ ] Splash → sign in anonymously → arrive sur Camera
- [ ] Changer de background → preview change dans la caméra
- [ ] Capture → Processing screen s'affiche avec les étapes animées
- [ ] Résultat s'affiche avec la photo relightée
- [ ] Save → sauvegarde dans Photos
- [ ] Share → share sheet
- [ ] Animate → paywall si free, génère vidéo si premium
- [ ] Gallery → filtres catégories fonctionnent
- [ ] Backgrounds premium verrouillés si free
