import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const REPLICATE_TOKEN = Deno.env.get("REPLICATE_API_TOKEN")!
const KLING_KEY = Deno.env.get("KLING_API_KEY")!

// ── Replicate polling helper ──────────────────────────────────────────────────
async function replicateRun(
  model: string,
  input: Record<string, unknown>
): Promise<string> {
  const res = await fetch(
    `https://api.replicate.com/v1/models/${model}/predictions`,
    {
      method: "POST",
      headers: {
        Authorization: `Token ${REPLICATE_TOKEN}`,
        "Content-Type": "application/json",
        Prefer: "wait=60",
      },
      body: JSON.stringify({ input }),
    }
  )

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Replicate error ${res.status}: ${text}`)
  }

  let prediction = await res.json()

  // Poll until done
  while (prediction.status !== "succeeded" && prediction.status !== "failed") {
    await new Promise((r) => setTimeout(r, 1500))
    const poll = await fetch(prediction.urls.get, {
      headers: { Authorization: `Token ${REPLICATE_TOKEN}` },
    })
    prediction = await poll.json()
  }

  if (prediction.status === "failed") {
    throw new Error(`Replicate prediction failed: ${prediction.error}`)
  }

  const output = prediction.output
  return Array.isArray(output) ? output[0] : output
}

// ── Kling polling helper ──────────────────────────────────────────────────────
async function klingAnimate(imageUrl: string): Promise<string | null> {
  const createRes = await fetch(
    "https://api.klingai.com/v1/videos/image2video",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${KLING_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "kling-v1",
        image: imageUrl,
        duration: "5",
        mode: "std",
        prompt: "subtle cinematic light movement, gentle atmosphere, portrait",
        cfg_scale: 0.5,
      }),
    }
  )

  if (!createRes.ok) return null
  const createData = await createRes.json()
  const taskId = createData?.data?.task_id
  if (!taskId) return null

  // Poll Kling job (max 2 minutes)
  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 3000))
    const poll = await fetch(
      `https://api.klingai.com/v1/videos/image2video/${taskId}`,
      { headers: { Authorization: `Bearer ${KLING_KEY}` } }
    )
    const pollData = await poll.json()
    const status = pollData?.data?.task_status
    if (status === "succeed") {
      return pollData?.data?.task_result?.videos?.[0]?.url ?? null
    }
    if (status === "failed") return null
  }

  return null // timeout
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    })
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 })
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Auth
    const authHeader = req.headers.get("Authorization") ?? ""
    const { data: authData, error: authError } =
      await supabase.auth.getUser(authHeader.replace("Bearer ", ""))
    if (authError || !authData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      })
    }
    const userId = authData.user.id

    // Parse form data
    const formData = await req.formData()
    const selfieFile = formData.get("selfie") as File | null
    const backgroundId = formData.get("backgroundId") as string | null
    const animate = formData.get("animate") === "true"

    if (!selfieFile || !backgroundId) {
      return new Response(
        JSON.stringify({ error: "Missing selfie or backgroundId" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // 1. Upload selfie to Supabase Storage
    const selfieBytes = await selfieFile.arrayBuffer()
    const selfieKey = `selfies/${userId}/${Date.now()}.jpg`
    const { error: uploadError } = await supabase.storage
      .from("generations")
      .upload(selfieKey, selfieBytes, { contentType: "image/jpeg" })

    if (uploadError) throw new Error(`Storage upload failed: ${uploadError.message}`)

    const { data: selfieUrlData } = supabase.storage
      .from("generations")
      .getPublicUrl(selfieKey)
    const selfieUrl = selfieUrlData.publicUrl

    // 2. Get background public URL
    const { data: bgUrlData } = supabase.storage
      .from("backgrounds")
      .getPublicUrl(`backgrounds/${backgroundId}.jpg`)
    const backgroundUrl = bgUrlData.publicUrl

    // 3. RMBG 2.0 — background removal
    const subjectUrl = await replicateRun(
      "lucataco/bria-rmbg-2.0",
      { image: selfieUrl }
    )

    // 4. IC-Light — relighting
    const relightedUrl = await replicateRun(
      "zsxkib/ic-light",
      {
        subject_image: subjectUrl,
        background_image: backgroundUrl,
        num_inference_steps: 25,
        guidance_scale: 1.5,
        output_format: "jpg",
      }
    )

    // 5. [Optional] Kling animation
    let animationUrl: string | null = null
    if (animate) {
      animationUrl = await klingAnimate(relightedUrl)
    }

    // 6. Save generation record
    const { data: gen, error: dbError } = await supabase
      .from("generations")
      .insert({
        user_id: userId,
        background_id: backgroundId,
        result_url: relightedUrl,
        animation_url: animationUrl,
        status: "done",
      })
      .select("id")
      .single()

    if (dbError) throw new Error(`DB insert failed: ${dbError.message}`)

    return new Response(
      JSON.stringify({
        generationId: gen.id,
        resultUrl: relightedUrl,
        animationUrl,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    )
  } catch (err) {
    console.error("Generation error:", err)
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    )
  }
})
