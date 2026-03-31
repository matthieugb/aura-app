// supabase/functions/revenuecat-webhook/index.ts
// RevenueCat → Supabase credit attribution
// Docs: https://www.revenuecat.com/docs/integrations/webhooks

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Credit amounts per product
const CREDIT_MAP: Record<string, number> = {
  aura_essai:       14,
  aura_recharge_s:  13,
  aura_recharge_m:  28,
  aura_recharge_l:  60,
  aura_mensuel:     33,   // per billing period
  aura_pro:         72,   // per billing period
  aura_annuel:      220,  // per year
}

// RevenueCat event types that should trigger credit attribution
const CREDIT_EVENTS = new Set([
  "NON_SUBSCRIPTION_PURCHASE",  // consumable packs
  "INITIAL_PURCHASE",           // first subscription payment
  "RENEWAL",                    // subscription renewal
  "UNCANCELLATION",             // user re-subscribes
])

serve(async (req: Request) => {
  try {
    // 1. Verify method
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 })
    }

    // 2. Verify RevenueCat shared secret
    const authHeader = req.headers.get("Authorization")
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")
    if (webhookSecret && authHeader !== webhookSecret) {
      console.error("Invalid webhook secret")
      return new Response("Unauthorized", { status: 401 })
    }

    // 3. Parse payload
    const payload = await req.json()
    const event = payload?.event

    if (!event) {
      return new Response("No event in payload", { status: 400 })
    }

    const eventType: string = event.type
    const productId: string = event.product_id
    const appUserId: string = event.app_user_id ?? event.original_app_user_id

    console.log(`RevenueCat event: ${eventType} | product: ${productId} | user: ${appUserId}`)

    // 4. Only process credit-bearing events
    if (!CREDIT_EVENTS.has(eventType)) {
      console.log(`Skipping event type: ${eventType}`)
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    // 5. Get credit amount
    const credits = CREDIT_MAP[productId]
    if (!credits) {
      console.warn(`Unknown product_id: ${productId}`)
      return new Response(JSON.stringify({ ok: true, unknown_product: productId }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    // 6. Validate user UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(appUserId)) {
      console.warn(`app_user_id is not a UUID: ${appUserId}. RC logIn() not called from app?`)
      return new Response(JSON.stringify({ ok: false, error: "invalid_user_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      })
    }

    // 7. Upsert credits in Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const { error } = await supabase.rpc("add_credits", {
      p_user_id: appUserId,
      p_amount: credits,
    })

    if (error) {
      console.error("Supabase error:", error)
      return new Response(JSON.stringify({ ok: false, error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      })
    }

    console.log(`✓ Added ${credits} credits to user ${appUserId} for ${productId}`)

    return new Response(
      JSON.stringify({ ok: true, user: appUserId, product: productId, credits }),
      { headers: { "Content-Type": "application/json" } }
    )

  } catch (err) {
    console.error("Webhook error:", err)
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})
