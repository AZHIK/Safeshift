'use client';

import type { ReactNode } from 'react';

/** A submit button that asks for confirmation before its form submits. */
export function ConfirmSubmit({
  message,
  className = 'btn btn-danger',
  disabled = false,
  children,
}: {
  message: string;
  className?: string;
  disabled?: boolean;
  children: ReactNode;
}) {
  return (
    <button
      type="submit"
      className={className}
      disabled={disabled}
      onClick={(event) => {
        if (!window.confirm(message)) event.preventDefault();
      }}
    >
      {children}
    </button>
  );
}
