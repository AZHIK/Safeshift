#!/usr/bin/env node
// Creates (or refreshes) the two accounts the integration tests sign in with,
// on a TEST Supabase project only:
//
//   it-admin@safeshift.test   super_admin, all countries
//   it-user@safeshift.test    no admin role (must be refused)
//
// Passwords are regenerated on every run and written, with the project URL and
// anon key, to SAFESHIFT_IT_CONFIG (default ~/.config/safeshift/integration-users.json,
// mode 600). Nothing is printed except a summary.
//
//   SUPABASE_URL=… SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… \
//     node apps/admin-console/scripts/provision-integration-users.mjs

import { randomBytes } from 'node:crypto';
import { chmodSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

const url = process.env.SUPABASE_URL?.replace(/\/$/, '');
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const out = process.env.SAFESHIFT_IT_CONFIG ?? join(homedir(), '.config/safeshift/integration-users.json');

if (!url || !anonKey || !serviceKey) {
  console.error('SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are required.');
  process.exit(1);
}

const headers = {
  apikey: serviceKey,
  authorization: `Bearer ${serviceKey}`,
  'content-type': 'application/json',
};

async function call(path, init = {}) {
  const res = await fetch(`${url}${path}`, { ...init, headers: { ...headers, ...(init.headers ?? {}) } });
  const text = await res.text();
  const body = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path} → ${res.status}: ${text.slice(0, 300)}`);
  return body;
}

async function findUser(email) {
  for (let page = 1; page < 50; page++) {
    const body = await call(`/auth/v1/admin/users?page=${page}&per_page=200`);
    const users = body.users ?? [];
    const hit = users.find((u) => u.email === email);
    if (hit) return hit;
    if (users.length < 200) return null;
  }
  return null;
}

async function upsertUser(email, fullName) {
  const password = randomBytes(24).toString('base64url');
  const existing = await findUser(email);
  const user = existing
    ? await call(`/auth/v1/admin/users/${existing.id}`, {
        method: 'PUT',
        body: JSON.stringify({ password, email_confirm: true }),
      })
    : await call('/auth/v1/admin/users', {
        method: 'POST',
        body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { full_name: fullName } }),
      });
  return { id: user.id, email, password };
}

async function ensureProfile(id, fullName, email) {
  await call('/rest/v1/profiles?on_conflict=id', {
    method: 'POST',
    headers: { prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify({ id, full_name: fullName, email, primary_role: 'customer' }),
  });
}

async function grantSuperAdmin(profileId) {
  const rows = await call(
    `/rest/v1/admin_roles?profile_id=eq.${profileId}&role_name=eq.super_admin&revoked_at=is.null&select=id`,
  );
  if (rows.length > 0) return;
  await call('/rest/v1/admin_roles', {
    method: 'POST',
    headers: { prefer: 'return=minimal' },
    body: JSON.stringify({ profile_id: profileId, role_name: 'super_admin', is_active: true }),
  });
}

const admin = await upsertUser('it-admin@safeshift.test', 'Integration Admin');
const user = await upsertUser('it-user@safeshift.test', 'Integration User');
await ensureProfile(admin.id, 'Integration Admin', admin.email);
await ensureProfile(user.id, 'Integration User', user.email);
await grantSuperAdmin(admin.id);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ url, anonKey, admin, user }, null, 2), { mode: 0o600 });
chmodSync(out, 0o600);
console.log(`Integration users ready (admin ${admin.id}, user ${user.id}). Config written to ${out}.`);
