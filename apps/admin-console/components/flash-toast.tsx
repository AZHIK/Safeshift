'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect } from 'react';

/**
 * Shows the outcome of a row action (?done= or ?failed=) on whatever page the
 * action returned to. Success messages clear themselves; errors stay until
 * dismissed.
 */
export function FlashToast() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const done = params.get('done');
  const failed = params.get('failed');
  const text = failed ?? done;

  const dismiss = useCallback(() => {
    const rest = new URLSearchParams(params);
    rest.delete('done');
    rest.delete('failed');
    router.replace(rest.size ? `${pathname}?${rest}` : pathname, { scroll: false });
  }, [params, pathname, router]);

  useEffect(() => {
    if (!done || failed) return;
    const timer = setTimeout(dismiss, 6000);
    return () => clearTimeout(timer);
  }, [done, failed, dismiss]);

  if (!text) return null;
  return (
    <div className={`flash-toast notice ${failed ? 'notice-error' : 'notice-ok'}`} role={failed ? 'alert' : 'status'}>
      <span>{text}</span>
      <button type="button" className="btn btn-sm" aria-label="Dismiss" onClick={dismiss}>
        ×
      </button>
    </div>
  );
}
