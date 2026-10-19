// Emails the public track link when a job is created, picked up, delivered, or failed.
// Secrets: optional RESEND_API_KEY, optional FROM_EMAIL, optional TRACK_PUBLIC_URL.
// Without RESEND_API_KEY the function returns skipped and the desk still works.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing Authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const userClient = createClient(supabaseUrl, supabaseAnon, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();
  if (userErr || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body: { job_id?: number } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const jobId = Number(body.job_id);
  if (!Number.isFinite(jobId)) {
    return json({ error: "job_id required" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: job, error: jobErr } = await admin
    .from("org_jobs")
    .select(
      "id, org_id, job_number, status, pickup_name, pickup_address, pickup_email, dropoff_name, dropoff_address, dropoff_email, customer_id, assigned_user_id, tracking_token",
    )
    .eq("id", jobId)
    .maybeSingle();
  if (jobErr) return json({ error: jobErr.message }, 500);
  if (!job) return json({ error: "Job not found" }, 404);

  const allowed = await canNotify(admin, user.id, job);
  if (!allowed) return json({ error: "Forbidden" }, 403);

  const emails = await collectEmails(admin, job);
  if (!emails.length) {
    return json({ ok: true, skipped: "no_recipients" });
  }

  const apiKey = Deno.env.get("RESEND_API_KEY") || "";
  if (!apiKey) {
    return json({ ok: true, skipped: "no_key" });
  }

  const origin = (Deno.env.get("TRACK_PUBLIC_URL") || "https://app.trektrack.pro")
    .replace(/\/$/, "");
  const track = job.tracking_token ? `${origin}/?track=${job.tracking_token}` : "";
  const status = statusLabel(job.status);
  const subject = job.job_number
    ? `TrekTrack job ${job.job_number} · ${status}`
    : `TrekTrack delivery · ${status}`;
  const lines = [
    job.job_number ? `Job ${job.job_number} is ${status}.` : `This delivery is ${status}.`,
    "",
  ];
  if (job.pickup_name || job.pickup_address) {
    lines.push(`Pickup: ${[job.pickup_name, job.pickup_address].filter(Boolean).join(" · ")}`);
  }
  if (job.dropoff_name || job.dropoff_address) {
    lines.push(`Delivery: ${[job.dropoff_name, job.dropoff_address].filter(Boolean).join(" · ")}`);
  }
  if (track) {
    lines.push("", `Track: ${track}`);
  }
  const from = Deno.env.get("FROM_EMAIL") || "TrekTrack <support.ultraforgellc@gmail.com>";

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: emails,
      subject,
      text: lines.join("\n"),
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    return json({ error: "Resend rejected mail", body: text }, 502);
  }
  return json({ ok: true, sent: emails.length });
});

async function canNotify(
  admin: ReturnType<typeof createClient>,
  userId: string,
  job: { org_id: string; assigned_user_id: string | null },
) {
  if (job.assigned_user_id && job.assigned_user_id === userId) return true;
  const { data } = await admin
    .from("org_members")
    .select("role")
    .eq("org_id", job.org_id)
    .eq("user_id", userId)
    .maybeSingle();
  return data?.role === "owner" || data?.role === "admin";
}

async function collectEmails(
  admin: ReturnType<typeof createClient>,
  job: { pickup_email: string; dropoff_email: string; customer_id: string | null },
) {
  const out: string[] = [];
  const add = (raw: unknown) => {
    const email = String(raw || "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return;
    if (!out.includes(email)) out.push(email);
  };
  add(job.pickup_email);
  add(job.dropoff_email);
  if (job.customer_id) {
    const { data } = await admin
      .from("org_customers")
      .select("billing_email")
      .eq("id", job.customer_id)
      .maybeSingle();
    add(data?.billing_email);
  }
  return out;
}

function statusLabel(status: string) {
  if (status === "picked_up") return "Picked up";
  if (status === "delivered" || status === "done") return "Delivered";
  if (status === "failed") return "Couldn't deliver";
  if (status === "cancelled") return "Cancelled";
  return "Scheduled";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
