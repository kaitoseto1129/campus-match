import { createBrowserClient } from "@supabase/ssr";

// ブラウザ(クライアントコンポーネント)側で使うSupabaseクライアント。
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  );
}
