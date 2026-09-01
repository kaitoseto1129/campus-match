import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// ログイン必須ページ(/discover, /profile 等)は /login へリダイレクトする。
// 未ログインでもアクセスしてよいページはここに列挙する。
// "/" はpage.tsx側で未ログイン時に/loginへリダイレクトするだけなので、
// ミドルウェアでも先に/loginへ流してしまって問題ない。
const PUBLIC_PATHS = ["/", "/login", "/signup", "/auth", "/reset-password"];

function isExactOrPrefixMatch(path: string, publicPath: string): boolean {
  if (publicPath === "/") return path === "/";
  return path.startsWith(publicPath);
}

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isPublicPath = PUBLIC_PATHS.some((p) => isExactOrPrefixMatch(path, p));

  if (!user && !isPublicPath) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  // メイン写真(order_number = 0)は必須。iOS版のRootGateViewと同様、
  // 未登録のユーザーはプロフィール編集画面以外に進めないようにする。
  const isProfileEditPath = isExactOrPrefixMatch(path, "/profile/edit");
  if (user && !isPublicPath && !isProfileEditPath) {
    const { count } = await supabase
      .from("profile_photos")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("order_number", 0);
    if (!count) {
      const url = request.nextUrl.clone();
      url.pathname = "/profile/edit";
      url.searchParams.set("required", "photo");
      return NextResponse.redirect(url);
    }
  }

  return supabaseResponse;
}
