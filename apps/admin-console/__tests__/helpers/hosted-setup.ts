import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';
import type { TestProject } from 'vitest/node';

function totp(secret: string) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  const bits = [...secret.toUpperCase().replace(/=+$/, '')].map(char => alphabet.indexOf(char).toString(2).padStart(5, '0')).join('');
  const key = Buffer.from((bits.match(/.{8}/g) ?? []).map(byte => parseInt(byte, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const hash = createHmac('sha1', key).update(counter).digest();
  return String((hash.readUInt32BE(hash[19] & 15) & 0x7fffffff) % 1000000).padStart(6, '0');
}

// Use one temporary factor for the explicitly provisioned integration account.
// All parallel suites reuse the same verified session.
export default async function setup(project: TestProject) {
  const path = process.env.SAFESHIFT_IT_CONFIG;
  if (!path) return;
  const { url, anonKey, admin } = JSON.parse(readFileSync(path, 'utf8'));
  if (admin.email !== 'it-admin@safeshift.test') throw new Error('Expected the dedicated integration admin.');
  const client = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const login = await client.auth.signInWithPassword({ email: admin.email, password: admin.password });
  if (login.error) throw login.error;
  const gate = await client.rpc('has_permission', { permission_key: 'manage_admins' });
  if (gate.error || gate.data !== false) throw new Error('Administrative permissions must require MFA.');
  const enroll = await client.auth.mfa.enroll({ factorType: 'totp' });
  if (enroll.error) throw enroll.error;
  const factorId = enroll.data.id;
  async function cleanup() {
    const { error } = await client.auth.mfa.unenroll({ factorId });
    if (error) throw error;
  }
  try {
    const session = await client.auth.mfa.challengeAndVerify({ factorId, code: totp(enroll.data.totp.secret) });
    if (session.error) throw session.error;
    project.provide('adminAccessToken', session.data.access_token);
  } catch (error) {
    await cleanup();
    throw error;
  }
  return cleanup;
}
