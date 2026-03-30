# AURA

**Step into the light.** — iOS app for AI-powered portrait relighting.

## Features

- 📸 Take a selfie and choose a background
- ✨ IC-Light relighting (state-of-the-art AI relighting)
- 🎬 Kling animation (Premium) — bring your portrait to life
- 🎨 8 curated backgrounds (3 free, 5 premium)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | Swift 5.9 / SwiftUI |
| Camera | AVFoundation |
| Auth & DB | Supabase |
| Backend | Supabase Edge Functions (Deno) |
| Segmentation | Replicate — RMBG 2.0 |
| Relighting | Replicate — IC-Light |
| Animation | Kling API |
| Payments | RevenueCat |

## Setup

1. Clone the repo
2. Copy `AURA/Config/Secrets.xcconfig.example` → `AURA/Config/Secrets.xcconfig`
3. Fill in your Supabase URL and keys
4. Open `AURA.xcodeproj` in Xcode 15+
5. Resolve SPM packages (automatic on first open)
6. Build and run on iOS 16+ device or simulator

## Backend Setup

See `supabase/README.md` for Edge Function deployment instructions.

## Cost Model

| Operation | Cost |
|-----------|------|
| Photo (RMBG + IC-Light) | ~$0.007 |
| Animation (+ Kling 5s) | ~$0.46–0.51 |

## Freemium

- **Free**: 5 photos/day, 3 backgrounds
- **Premium ($14.99/mo)**: Unlimited photos, 20 Kling animations/mo, full catalog
