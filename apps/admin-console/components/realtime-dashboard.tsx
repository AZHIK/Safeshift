'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

import { getBrowserClient } from '@/lib/supabase/client';

const tables = [
  'jobs',
  'incidents',
  'support_tickets',
  'disputes',
  'verification_requests',
  'trip_alerts',
];

export function RealtimeDashboard() {
  const router = useRouter();
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const supabase = getBrowserClient();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const channel = supabase.channel('admin-dashboard-live');
    for (const table of tables) {
      channel.on(
        'postgres_changes',
        { event: '*', schema: 'public', table },
        () => {
          if (timer) clearTimeout(timer);
          timer = setTimeout(() => router.refresh(), 400);
        },
      );
    }
    channel.subscribe((status: string) => setConnected(status === 'SUBSCRIBED'));
    return () => {
      if (timer) clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  }, [router]);

  return (
    <span className="live">
      <span className="live-dot" style={{ background: connected ? undefined : '#b77900' }} />
      {connected ? 'Live updates on' : 'Connecting live updates…'}
    </span>
  );
}
