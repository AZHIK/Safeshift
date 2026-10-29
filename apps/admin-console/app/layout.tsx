import type { Metadata } from 'next';

import './globals.css';

export const metadata: Metadata = {
  title: 'SafeShift Console',
  description: 'Operations, trust & safety, finance, and fleet console',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
