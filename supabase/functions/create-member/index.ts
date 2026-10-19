// Owner/admin opens a TrekTrack login for a teammate (email and/or phone).
// Uses the service role. Phone provider must be on for phone sign-in.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return json({ ok: true }, 200);
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization" }, 401);

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
  if (userErr || !user) return json({ error: "Unauthorized" }, 401);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const orgId = String(body.org_id || "");
  const email = String(body.email || "").trim().toLowerCase();
  const phone = toE164(String(body.phone || ""));
  const password = String(body.password || "");
  const role = String(body.role || "driver").toLowerCase();
  const firstName = String(body.first_name || "").trim();
  const lastName = String(body.last_name || "").trim();
  const driverNumber = String(body.driver_number || "").trim() || null;
  const accessIn = (body.access && typeof body.access === "object")
    ? body.access as Record<string, unknown>
    : {};

  if (!orgId) return json({ error: "Missing team" }, 400);
  if (!email && !phone) return json({ error: "Enter an email or a phone number" }, 400);
  if (email && !email.includes("@")) return json({ error: "Enter a valid email" }, 400);
  if (String(body.phone || "").trim() && !phone) {
    return json({ error: "Enter a valid phone number" }, 400);
  }
  if (password.length < 6) {
    return json({ error: "Password must be at least 6 characters" }, 400);
  }
  if (!["admin", "dispatcher", "driver"].includes(role)) {
    return json({ error: "Role must be admin, dispatcher, or driver" }, 400);
  }
  if (firstName.length > 40 || lastName.length > 40) {
    return json({ error: "Name is too long" }, 400);
  }
  if (driverNumber && driverNumber.length > 12) {
    return json({ error: "Driver number is too long" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: me, error: meErr } = await admin
    .from("org_members")
    .select("role")
    .eq("org_id", orgId)
    .eq("user_id", user.id)
    .maybeSingle();
  if (meErr) return json({ error: meErr.message }, 500);
  if (me?.role !== "owner" && me?.role !== "admin") {
    return json({ error: "Only the owner or an admin can add people" }, 403);
  }

  const { data: org, error: orgErr } = await admin
    .from("orgs")
    .select("default_pay_type")
    .eq("id", orgId)
    .maybeSingle();
  if (orgErr) return json({ error: orgErr.message }, 500);
  const payType = org?.default_pay_type || "contractor";

  const attrs: Record<string, unknown> = {
    password,
    email_confirm: true,
    phone_confirm: true,
    user_metadata: { first_name: firstName, last_name: lastName },
  };
  if (email) attrs.email = email;
  if (phone) attrs.phone = phone;

  const created = await admin.auth.admin.createUser(attrs);
  if (created.error || !created.data.user) {
    return json({ error: created.error?.message || "Could not create account" }, 400);
  }
  const newUser = created.data.user;

  const access = normalizeAccess(role, accessIn);
  const display = [firstName, lastName].filter(Boolean).join(" ");
  const { error: memErr } = await admin.from("org_members").insert({
    org_id: orgId,
    user_id: newUser.id,
    role,
    access,
    pay_type: payType,
    driver_number: driverNumber,
  });
  if (memErr) {
    await admin.auth.admin.deleteUser(newUser.id);
    return json({ error: memErr.message }, 400);
  }

  const { error: profErr } = await admin.from("profiles").upsert({
    user_id: newUser.id,
    nickname: display,
    first_name: firstName,
    last_name: lastName,
    phone: phone || "",
    updated_at: new Date().toISOString(),
  });
  if (profErr) {
    return json({ error: profErr.message }, 400);
  }

  return json({
    ok: true,
    user_id: newUser.id,
    email: email || null,
    phone: phone || null,
  });
});

function normalizeAccess(role: string, src: Record<string, unknown>) {
  if (role === "owner" || role === "admin") {
    return {
      today: true, plan: true, review: true, books: true, people: true, settings: true,
    };
  }
  if (role !== "dispatcher") {
    return {
      today: false, plan: false, review: false, books: false, people: false, settings: false,
    };
  }
  const flag = (key: string, fallback: boolean) => {
    const v = src[key];
    if (v === true || v === false) return v;
    return fallback;
  };
  return {
    today: flag("today", true),
    plan: flag("plan", true),
    review: flag("review", true),
    books: flag("books", false),
    people: false,
    settings: false,
  };
}

function toE164(value: string) {
  const raw = value.trim();
  if (!raw) return "";
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  if (raw.startsWith("+") && digits.length >= 10) return `+${digits}`;
  if (digits.length >= 10 && digits.length <= 15) return `+${digits}`;
  return "";
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
