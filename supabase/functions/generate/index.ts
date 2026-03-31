import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-user-token",
}

// Credit costs per model
const CREDIT_COSTS: Record<string, number> = {
  nanobanana: 1,
  kling_v25_5s: 6,
  kling_v25_10s: 11,
  kling_v3_5s: 10,
  kling_v3_10s: 18,
  omnihuman_5s: 12,
  omnihuman_10s: 20,
}

// ── Kling JWT ─────────────────────────────────────────────────────────────────
async function klingJWT(): Promise<string> {
  const accessKey = Deno.env.get("KLING_ACCESS_KEY")!
  const secretKey = Deno.env.get("KLING_SECRET_KEY")!
  const now = Math.floor(Date.now() / 1000)
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))
  const payload = btoa(JSON.stringify({ iss: accessKey, exp: now + 1800, nbf: now - 5 }))
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secretKey), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  )
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(`${header}.${payload}`))
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
  return `${header}.${payload}.${sigB64}`
}

// ── Kling Image ───────────────────────────────────────────────────────────────
async function klingGenerateImage(referenceImageUrls: string[], prompt: string, aspectRatio = "9:16"): Promise<string[]> {
  const jwt = await klingJWT()
  const res = await fetch("https://api.klingai.com/v1/images/generations", {
    method: "POST",
    headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model_name: "kling-v1-5",
      prompt,
      negative_prompt: "blur, low quality, distorted, extra limbs, watermark",
      aspect_ratio: aspectRatio,
      image_count: 2,
      image_references: referenceImageUrls.map((url) => ({ type: "subject", url })),
      cfg_scale: 0.5,
    }),
  })
  if (!res.ok) throw new Error(`Kling image error ${res.status}: ${await res.text()}`)
  const data = await res.json()
  const taskId = data?.data?.task_id
  if (!taskId) throw new Error("Kling: no task_id returned")
  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 3000))
    const poll = await fetch(`https://api.klingai.com/v1/images/generations/${taskId}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    })
    const pollData = await poll.json()
    const status = pollData?.data?.task_status
    if (status === "succeed") {
      const images = pollData?.data?.task_result?.images ?? []
      const urls = images.map((img: { url: string }) => img.url).filter(Boolean)
      if (urls.length === 0) throw new Error("Kling: no image URLs in result")
      return urls
    }
    if (status === "failed") throw new Error(`Kling image failed`)
  }
  throw new Error("Kling image generation timed out")
}

// ── Google Gemini 2.0 Flash Image Generation (direct API) ────────────────────
async function geminiGenerate(
  imageBytes: Uint8Array[],
  prompt: string,
  aspectRatio = "9:16",
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<string[]> {
  const googleKey = Deno.env.get("GOOGLE_AI_API_KEY")
  // Fallback to fal.ai if no Google key configured
  if (!googleKey) {
    console.log("No GOOGLE_AI_API_KEY, falling back to fal.ai")
    return falNanobanana([], prompt, aspectRatio, imageBytes)
  }

  // Build multimodal parts: images first, then prompt
  const parts: any[] = imageBytes.map(bytes => ({
    inline_data: {
      mime_type: "image/jpeg",
      data: btoa(String.fromCharCode(...bytes))
    }
  }))
  parts.push({ text: prompt })

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=${googleKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          responseModalities: ["IMAGE"],
          candidateCount: 2,
        }
      })
    }
  )

  const rawText = await res.text()
  if (!res.ok) {
    console.error("Gemini error, falling back to fal.ai:", rawText.slice(0, 300))
    return falNanobanana([], prompt, aspectRatio, imageBytes)
  }

  let data: any
  try { data = JSON.parse(rawText) } catch {
    console.error("Gemini invalid JSON, falling back:", rawText.slice(0, 200))
    return falNanobanana([], prompt, aspectRatio, imageBytes)
  }

  // Extract base64 images and upload to Supabase storage
  const candidates = data?.candidates ?? []
  const resultUrls: string[] = []

  for (let i = 0; i < candidates.length; i++) {
    const imgPart = candidates[i]?.content?.parts?.find((p: any) => p.inline_data?.data)
    if (!imgPart) continue
    const imgBytes = Uint8Array.from(atob(imgPart.inline_data.data), c => c.charCodeAt(0))
    const key = `generated/${userId}/${Date.now()}_${i}.jpg`
    const { error } = await supabase.storage.from("generations").upload(key, imgBytes, { contentType: "image/jpeg" })
    if (!error) {
      const { data: urlData } = supabase.storage.from("generations").getPublicUrl(key)
      resultUrls.push(urlData.publicUrl)
    }
  }

  if (resultUrls.length === 0) {
    console.log("Gemini returned no images, falling back to fal.ai")
    return falNanobanana([], prompt, aspectRatio, imageBytes)
  }
  return resultUrls
}

// ── fal.ai Nano Banana 2 Edit (fallback) ─────────────────────────────────────
async function falNanobanana(imageUrls: string[], prompt: string, aspectRatio = "9:16", rawBytes?: Uint8Array[]): Promise<string[]> {
  const falKey = Deno.env.get("FAL_API_KEY")!

  // If we have raw bytes but no URLs, we can't use fal.ai (needs URLs) — return empty
  if (imageUrls.length === 0 && (!rawBytes || rawBytes.length === 0)) {
    throw new Error("fal.ai: no image URLs provided")
  }

  const res = await fetch("https://fal.run/fal-ai/nano-banana-2/edit", {
    method: "POST",
    headers: { Authorization: `Key ${falKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      prompt,
      image_urls: imageUrls,
      num_images: 2,
      aspect_ratio: aspectRatio,
      resolution: "1K",
      limit_generations: true,
    }),
  })

  const rawText = await res.text()
  if (!res.ok) throw new Error(`fal.ai error ${res.status}: ${rawText}`)

  let data: any
  try {
    data = JSON.parse(rawText)
  } catch {
    throw new Error(`fal.ai invalid JSON: ${rawText.slice(0, 200)}`)
  }

  const urls = (data?.images ?? []).map((img: { url: string }) => img.url).filter(Boolean)
  if (urls.length === 0) throw new Error(`fal.ai: no images returned — ${rawText.slice(0, 300)}`)
  return urls
}

// ── Safe JSON parse helper ───────────────────────────────────────────────────
function safeJsonParse(text: string, context: string): any {
  if (!text || text.trim().length === 0) throw new Error(`${context}: empty response body`)
  try { return JSON.parse(text) }
  catch { throw new Error(`${context}: invalid JSON — ${text.slice(0, 300)}`) }
}

// ── fal.ai video helper (submit + poll) ─────────────────────────────────────
async function falVideoGenerate(
  endpoint: string,
  payload: Record<string, unknown>,
  label: string
): Promise<string> {
  const falKey = Deno.env.get("FAL_API_KEY")!
  const baseUrl = `https://queue.fal.run/${endpoint}`

  // Submit
  console.log(`[${label}] Submitting to ${baseUrl}`)
  const submitRes = await fetch(baseUrl, {
    method: "POST",
    headers: { Authorization: `Key ${falKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  })
  const submitText = await submitRes.text()
  console.log(`[${label}] Submit response ${submitRes.status}: ${submitText.slice(0, 200)}`)
  if (!submitRes.ok) throw new Error(`${label} submit error ${submitRes.status}: ${submitText.slice(0, 300)}`)
  const submitData = safeJsonParse(submitText, `${label} submit`)
  const request_id = submitData.request_id
  if (!request_id) throw new Error(`${label}: no request_id — ${submitText.slice(0, 300)}`)

  // Use URLs returned by fal.ai directly
  const statusUrl = submitData.status_url ?? `${baseUrl}/requests/${request_id}/status`
  const responseUrl = submitData.response_url ?? `${baseUrl}/requests/${request_id}`
  console.log(`[${label}] status_url: ${statusUrl}`)

  // Poll
  for (let i = 0; i < 70; i++) {
    await new Promise((r) => setTimeout(r, 5000))
    const statusRes = await fetch(statusUrl, {
      headers: { Authorization: `Key ${falKey}` },
    })
    const statusText = await statusRes.text()
    if (!statusText || statusText.trim().length === 0) {
      console.log(`[${label}] Poll ${i}: empty body, retrying...`)
      continue
    }
    const statusData = safeJsonParse(statusText, `${label} poll`)
    console.log(`[${label}] Poll ${i}: ${statusData.status}`)

    if (statusData.status === "COMPLETED") {
      const resultRes = await fetch(responseUrl, {
        headers: { Authorization: `Key ${falKey}` },
      })
      const resultText = await resultRes.text()
      const resultData = safeJsonParse(resultText, `${label} result`)
      const url = resultData?.video?.url
      if (!url) throw new Error(`${label}: no video URL — ${resultText.slice(0, 300)}`)
      return url
    }
    if (statusData.status === "FAILED") {
      throw new Error(`${label}: generation failed — ${statusText.slice(0, 300)}`)
    }
  }
  throw new Error(`${label}: timed out after 350s`)
}

// ── Kling v3 Pro Video (fal.ai) ───────────────────────────────────────────────
async function klingV3Animate(imageUrl: string, prompt: string, duration: 5 | 10 = 5): Promise<string> {
  return falVideoGenerate("fal-ai/kling-video/v3/pro/image-to-video", {
    image_url: imageUrl,
    prompt: prompt + ", subtle cinematic motion, gentle warm light, film grain",
    duration: String(duration),
    negative_prompt: "blur, distort, low quality, static, frozen",
    cfg_scale: 0.5,
  }, "Kling v3")
}

// ── Kling v2.5 Turbo Video (fal.ai) ──────────────────────────────────────────
async function klingV25Animate(imageUrl: string, prompt: string, duration: 5 | 10 = 5): Promise<string> {
  return falVideoGenerate("fal-ai/kling-video/v2.5-turbo/pro/image-to-video", {
    image_url: imageUrl,
    prompt: prompt + ", subtle cinematic motion, gentle warm light",
    duration: String(duration),
    negative_prompt: "blur, distort, low quality, static, frozen",
    cfg_scale: 0.5,
  }, "Kling v2.5")
}

// ── Kling AI Avatar — image + voice → lip sync video (fal.ai) ────────────────
async function omniHumanAnimate(imageUrl: string, audioUrl: string): Promise<string | null> {
  try {
    const falKey = Deno.env.get("FAL_API_KEY")!
    const submitRes = await fetch("https://queue.fal.run/fal-ai/kling-video/v1/pro/ai-avatar", {
      method: "POST",
      headers: { Authorization: `Key ${falKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ image_url: imageUrl, audio_url: audioUrl }),
    })
    if (!submitRes.ok) return null
    const { request_id } = await submitRes.json()
    if (!request_id) return null
    for (let i = 0; i < 60; i++) {
      await new Promise((r) => setTimeout(r, 4000))
      const statusRes = await fetch(
        `https://queue.fal.run/fal-ai/kling-video/v1/pro/ai-avatar/requests/${request_id}/status`,
        { headers: { Authorization: `Key ${falKey}` } }
      )
      const { status } = await statusRes.json()
      if (status === "COMPLETED") {
        const resultRes = await fetch(
          `https://queue.fal.run/fal-ai/kling-video/v1/pro/ai-avatar/requests/${request_id}`,
          { headers: { Authorization: `Key ${falKey}` } }
        )
        const data = await resultRes.json()
        return data?.video?.url ?? null
      }
      if (status === "FAILED") return null
    }
    return null
  } catch { return null }
}

// ── Credits helpers ───────────────────────────────────────────────────────────
async function checkAndDeductCredits(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  model: string,
  isDailyFree: boolean,
  deduct: boolean
): Promise<{ ok: boolean; balance?: number; cost: number; error?: string }> {
  const cost = isDailyFree ? 0 : (CREDIT_COSTS[model] ?? 1)

  const { data: row } = await supabase
    .from("user_credits").select("balance, last_daily_claim").eq("user_id", userId).single()

  if (!row) {
    await supabase.from("user_credits").insert({ user_id: userId, balance: 5 })
    if (cost > 5) return { ok: false, cost, error: `Not enough credits (need ${cost}, have 5)` }
    return { ok: true, balance: 5, cost }
  }

  if (row.balance < cost) return { ok: false, cost, error: `Not enough credits (need ${cost}, have ${row.balance})` }

  if (!deduct) return { ok: true, balance: row.balance, cost }

  // Actually deduct
  if (isDailyFree) {
    await supabase.from("user_credits").update({ last_daily_claim: new Date().toISOString() }).eq("user_id", userId)
    return { ok: true, balance: row.balance, cost }
  }
  const newBalance = row.balance - cost
  await supabase.from("user_credits").update({ balance: newBalance, updated_at: new Date().toISOString() }).eq("user_id", userId)
  return { ok: true, balance: newBalance, cost }
}

function isDailyFreeEligible(lastClaim: string | null): boolean {
  if (!lastClaim) return true
  const last = new Date(lastClaim)
  const now = new Date()
  return (now.getTime() - last.getTime()) > 24 * 60 * 60 * 1000
}

// ── Main handler ──────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 })

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const userToken = req.headers.get("x-user-token") ?? req.headers.get("Authorization")?.replace("Bearer ", "") ?? ""
    const { data: authData, error: authError } = await supabase.auth.getUser(userToken)
    if (authError || !authData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      })
    }
    const userId = authData.user.id

    let formData: FormData
    try {
      formData = await req.formData()
    } catch (e) {
      return new Response(JSON.stringify({ error: `FormData parse failed: ${(e as Error).message}` }), {
        status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      })
    }
    const prompt = (formData.get("prompt") as string) || ""
    const model = (formData.get("model") as string) || "nanobanana"
    const aspectRatio = (formData.get("aspect_ratio") as string) || "9:16"
    const videoDuration = (formData.get("video_duration") as string) || "5"
    const animateSourceUrl = (formData.get("animate_source_url") as string) || null

    // Check daily free eligibility (nanobanana only)
    let dailyFree = false
    if (model === "nanobanana") {
      const { data: credits } = await supabase.from("user_credits")
        .select("last_daily_claim").eq("user_id", userId).single()
      dailyFree = isDailyFreeEligible(credits?.last_daily_claim ?? null)
    }

    // Check credits (don't deduct yet)
    const creditCheck = await checkAndDeductCredits(supabase, userId, model, dailyFree, false)
    if (!creditCheck.ok) {
      return new Response(JSON.stringify({ error: creditCheck.error, insufficientCredits: true }), {
        status: 402, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      })
    }

    // Collect selfie files
    const selfieUrls: string[] = []
    const selfieBytes: Uint8Array[] = []
    for (let i = 0; i < 5; i++) {
      const file = formData.get(`selfie_${i}`) as File | null
      if (!file) break
      const bytes = await file.arrayBuffer()
      selfieBytes.push(new Uint8Array(bytes))
      const key = `selfies/${userId}/${Date.now()}_${i}.jpg`
      const { error: uploadError } = await supabase.storage
        .from("generations").upload(key, bytes, { contentType: "image/jpeg" })
      if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`)
      const { data: urlData } = supabase.storage.from("generations").getPublicUrl(key)
      selfieUrls.push(urlData.publicUrl)
    }

    // For animation models, animateSourceUrl replaces selfies
    const isAnimationModel = model.startsWith("kling_v") || model.startsWith("omnihuman")
    if (!isAnimationModel && selfieUrls.length === 0) {
      return new Response(JSON.stringify({ error: "Missing selfies or prompt" }), {
        status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      })
    }
    if (!prompt) {
      return new Response(JSON.stringify({ error: "Missing prompt" }), {
        status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      })
    }

    // Generate based on model
    let resultUrls: string[] = []
    let animationUrl: string | null = null

    if (model === "nanobanana") {
      const facedPrompt = `Put this exact person from the reference image into the following scene, keeping their face, features, skin tone and hair identical: ${prompt}. Beautiful cinematic shot, minimal, natural light.`
      resultUrls = await falNanobanana(selfieUrls, facedPrompt, aspectRatio)
    } else if (model === "kling_image") {
      resultUrls = await klingGenerateImage(selfieUrls, prompt, aspectRatio)
    } else if (model === "kling_v25_5s" || model === "kling_v25_10s") {
      const sourceUrl = animateSourceUrl ?? selfieUrls[0]
      const duration = model === "kling_v25_10s" ? 10 : 5
      animationUrl = await klingV25Animate(sourceUrl, prompt, duration as 5 | 10)
      resultUrls = animationUrl ? [animationUrl] : []
    } else if (model === "kling_v3_5s" || model === "kling_v3_10s") {
      const sourceUrl = animateSourceUrl ?? selfieUrls[0]
      const duration = model === "kling_v3_10s" ? 10 : 5
      animationUrl = await klingV3Animate(sourceUrl, prompt, duration as 5 | 10)
      resultUrls = animationUrl ? [animationUrl] : []
    } else if (model === "omnihuman_5s" || model === "omnihuman_10s") {
      // Upload audio first
      const audioFile = formData.get("audio") as File | null
      if (audioFile) {
        const audioBytes = await audioFile.arrayBuffer()
        const audioKey = `audio/${userId}/${Date.now()}_voice.m4a`
        const { error: audioUploadError } = await supabase.storage
          .from("generations").upload(audioKey, audioBytes, { contentType: "audio/m4a" })
        if (!audioUploadError) {
          const { data: audioUrlData } = supabase.storage.from("generations").getPublicUrl(audioKey)
          animationUrl = await omniHumanAnimate(selfieUrls[0], audioUrlData.publicUrl)
          resultUrls = animationUrl ? [animationUrl] : []
        }
      }
    }

    // Deduct credits only after successful generation
    const creditResult = await checkAndDeductCredits(supabase, userId, model, dailyFree, true)

    // Save to DB
    const { data: gen, error: dbError } = await supabase
      .from("generations")
      .insert({ user_id: userId, prompt, result_urls: resultUrls, animation_url: animationUrl, status: "done", model })
      .select("id").single()
    if (dbError) throw new Error(`DB insert: ${dbError.message}`)

    return new Response(
      JSON.stringify({
        generationId: gen.id,
        resultUrls,
        animationUrl,
        creditsRemaining: creditResult.balance,
        dailyFreeUsed: dailyFree,
      }),
      { headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    )
  } catch (err) {
    console.error("Generation error:", err)
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    )
  }
})
