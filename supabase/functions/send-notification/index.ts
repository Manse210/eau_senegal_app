import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  record: { id: string; status: string; boutiquier_id: string };
  old_record: { status: string };
}

const MESSAGES: Record<string, string> = {
  confirmee: "Votre commande a été confirmée",
  en_livraison: "Votre commande est en livraison",
  livree: "Votre commande a été livrée",
  annulee: "Votre commande a été annulée",
  payee: "Paiement confirmé pour votre commande",
};

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    if (payload.type !== "UPDATE") return new Response("Ignored", { status: 200 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profile } = await supabase
      .from("profiles").select("fcm_token")
      .eq("id", payload.record.boutiquier_id).single();

    if (!profile?.fcm_token) return new Response("No FCM token", { status: 200 });

    const body = MESSAGES[payload.record.status];
    if (!body) return new Response("No message for this status", { status: 200 });

    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const accessToken = await getAccessToken(serviceAccount);

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: { title: "sen-eau", body },
            data: {
              commande_id: payload.record.id,
              status: payload.record.status,
            },
          },
        }),
      },
    );

    const result = await fcmRes.text();
    return new Response(result, { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
