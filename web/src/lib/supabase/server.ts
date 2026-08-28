import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Server Components / Route Handlers 側で使うSupabaseクライアント。
// Cookieベースのセッションを読み書きするため、呼び出し側でasync関数にする必要がある。
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Server ComponentからsetAllが呼ばれた場合は無視してよい
            // (middlewareがセッションのリフレッシュを担当しているため)。
          }
        },
      },
    }
  );
}
