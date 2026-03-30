# AURA — Design Document
_2026-03-30_

## Overview

iOS app (Swift natif) permettant à un utilisateur de se prendre en selfie et de se placer dans un background avec une lumière cohérente et réaliste, grâce à IC-Light (relighting) et Kling (animation vidéo).

**Nom de l'app :** AURA
**Tagline :** "Step into the light."
**Cible :** Grand public, freemium
**Plateforme :** iOS natif (Swift)

---

## Architecture

```
iPhone (Swift / SwiftUI)
    │
    ├── AVFoundation — capture selfie
    ├── Background picker — catalogue + upload
    └── HTTPS → Backend API (Node.js / Supabase Edge Functions)
                │
                ├── Replicate: RMBG 2.0 — segmentation du sujet
                ├── Replicate: IC-Light — relighting conditionné par le background
                ├── [Premium] Kling API — animation image-to-video (5s)
                └── Supabase Storage — stockage résultats + catalogue backgrounds
```

**Auth & DB :** Supabase (users, credits, galerie)
**Paiement :** RevenueCat (freemium + subscription iOS)

---

## Pipeline de génération

### Photo statique (Free tier)
1. Upload selfie + background → backend
2. RMBG 2.0 — supprime le fond du selfie
3. IC-Light — relight le sujet selon l'éclairage du background
4. Composite final → Supabase Storage
5. URL retournée → affichage dans l'app

**Coût :** ~$0.007 par génération

### Photo animée (Premium)
1–4. Idem photo statique
5. IC-Light output → Kling Image-to-Video (5s)
6. Vidéo stockée → Supabase Storage

**Coût :** ~$0.46–0.51 par génération

---

## Modèle économique

| Tier | Prix | Inclus |
|------|------|--------|
| Free | Gratuit | 5 photos statiques/jour, 3 backgrounds |
| Premium | $14.99/mois | Photos illimitées, catalogue complet, 20 animations Kling/mois |
| Credits | $0.99/crédit | 1 animation Kling à l'unité (achat in-app) |

---

## Backgrounds

- **Catalogue curated** : ~20 backgrounds générés par IA (Midjourney/Flux), categorisés : Studio, Nature, Urban, Luxury
- **Upload custom** : Premium uniquement
- Assets hébergés sur Supabase Storage
- 3 backgrounds gratuits : Golden Hour, Forest, Night City

---

## Écrans (5 screens)

1. **Splash** — Identité AURA, strips de backgrounds en arrière-plan, CTA "Get Started"
2. **Camera** — AVFoundation fullscreen, guide ovale, strip de backgrounds scrollable en bas, bouton capture circulaire
3. **Gallery** — Grille 2 colonnes avec catégories, badges Free / ★ Premium
4. **Processing** — Animation IC-Light sweep, 3 étapes avec indicateurs (RMBG → IC-Light → Composite)
5. **Result** — Image finale, actions Save / Share / Animate ✦ (Kling premium), compteur de crédits

---

## Design System

- **Typographie :** Cormorant Garamond (display, 300–600) + DM Sans (UI, 300–500)
- **Couleurs :**
  - Cream `#F7F3ED` — background principal
  - Dark `#18120C` — textes, surfaces sombres
  - Gold `#C4894A` — accent principal, CTA premium
  - Sand `#EAE0D2` — séparateurs, surfaces secondaires
  - Muted `#9A8878` — labels, metadata
- **Tone :** Editorial luxury, solaire, aéré — Slim Aarons. Jamais baroque.

---

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| App iOS | Swift / SwiftUI |
| Caméra | AVFoundation |
| Auth | Supabase Auth |
| DB | Supabase Postgres |
| Storage | Supabase Storage |
| Backend | Supabase Edge Functions (Deno) |
| Segmentation | Replicate — RMBG 2.0 |
| Relighting | Replicate — IC-Light |
| Animation | Kling API |
| Paiement | RevenueCat |

---

## Coûts API (résumé)

| Étape | Modèle | Coût/génération |
|-------|--------|-----------------|
| Segmentation | RMBG 2.0 (Replicate) | ~$0.004 |
| Relighting | IC-Light (Replicate) | ~$0.003 |
| Animation | Kling API (5s vidéo) | ~$0.46–0.50 |

**Break-even premium ($14.99/mois) :** ~30 animations Kling par user — au-delà, marge positive.
