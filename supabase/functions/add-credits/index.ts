import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )
  const { data, error } = await supabase.from("user_credits").update({ balance: 100 }).gte("balance", 0).select()
  return new Response(JSON.stringify({ updated: data?.length, error }), {
    headers: { "Content-Type": "application/json" }
  })
})
