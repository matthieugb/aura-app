# Supabase Backend

## Setup

1. Install Supabase CLI: `brew install supabase/tap/supabase`
2. Login: `supabase login`
3. Link project: `supabase link --project-ref YOUR_PROJECT_REF`
4. Run migration: `supabase db push`

## Deploy Edge Function

Set secrets:
```bash
supabase secrets set REPLICATE_API_TOKEN=r8_xxx
supabase secrets set KLING_API_KEY=xxx
```

Deploy:
```bash
supabase functions deploy generate
```

## Test

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/generate \
  -H "Authorization: Bearer USER_JWT" \
  -F "selfie=@test.jpg" \
  -F "backgroundId=golden-hour" \
  -F "animate=false"
```

Expected response in ~15s:
```json
{"generationId":"uuid","resultUrl":"https://...","animationUrl":null}
```

## Storage Buckets Required

Create in Supabase Dashboard → Storage:
- `generations` (private, RLS)
- `backgrounds` (public)
