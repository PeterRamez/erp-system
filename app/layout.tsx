import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Hair Clinic OS', description: 'Clinic operations and hair transplant management' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ar" dir="rtl"><body>{children}</body></html>;
}
