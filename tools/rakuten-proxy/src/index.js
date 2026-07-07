// 楽天 Books API 用 CORS プロキシ Worker。
//
// Flutter Web / Android エミュレータから楽天 API を叩けるようにする中継。
//   - 楽天 API は CORS ヘッダを返さないためブラウザから直接呼べない
//   - applicationId / accessKey を Worker 側の secret に持たせて Flutter 側から隠す
//
// パス設計:
//   /books/search   → BooksBook/Search/20170404
//   /books/genre    → BooksGenre/Search/20121128
//   /image?url=...  → 楽天サムネイル画像 (CORS ヘッダを付与して中継)
//
// レスポンスの *ImageUrl フィールドは自動で /image エンドポイント経由に
// 書き換える。これで Flutter Web でも CachedNetworkImage が動く
// (CachedNetworkImage は XHR 経由で画像バイトを取るため CORS が必要)。

const RAKUTEN_ENDPOINTS = {
  '/books/search': 'https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404',
  '/books/genre': 'https://openapi.rakuten.co.jp/services/api/BooksGenre/Search/20121128',
};

// 楽天のサムネイル画像ホスト。ここから来た URL だけを画像プロキシで通す
// (open-redirect 化を防ぐため任意 URL は転送しない)。
const IMAGE_HOST_ALLOWLIST = [
  'thumbnail.image.rakuten.co.jp',
  'shop.r10s.jp',
];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname === '/image') {
      return handleImage(url);
    }

    const upstream = RAKUTEN_ENDPOINTS[url.pathname];
    if (!upstream) {
      return json({ error: 'not_found', path: url.pathname }, 404);
    }

    if (!env.RAKUTEN_APP_ID || !env.RAKUTEN_ACCESS_KEY) {
      return json({ error: 'server_misconfigured' }, 500);
    }

    const outUrl = new URL(upstream);
    for (const [k, v] of url.searchParams.entries()) {
      if (k === 'applicationId' || k === 'accessKey') continue;
      outUrl.searchParams.set(k, v);
    }
    outUrl.searchParams.set('applicationId', env.RAKUTEN_APP_ID);
    outUrl.searchParams.set('accessKey', env.RAKUTEN_ACCESS_KEY);
    outUrl.searchParams.set('format', 'json');

    try {
      const resp = await fetch(outUrl.toString(), {
        headers: { 'User-Agent': 'reading-log-proxy/1.0' },
      });

      const body = await resp.text();
      // Book Search のレスポンスにはサムネイル画像 URL が含まれるので、
      // Worker 経由に書き換える (Web でも <img>/XHR どちらでも読めるようにするため)。
      const rewritten = resp.ok ? rewriteImageUrls(body, url.origin) : body;

      return new Response(rewritten, {
        status: resp.status,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': resp.headers.get('Content-Type') || 'application/json',
          'Cache-Control': 'public, max-age=300',
        },
      });
    } catch (err) {
      return json({ error: 'upstream_failed', message: String(err) }, 502);
    }
  },
};

/// 楽天のサムネイル画像を中継する。CORS ヘッダを付与するだけの薄い経路。
async function handleImage(url) {
  const target = url.searchParams.get('url');
  if (!target) return json({ error: 'missing_url' }, 400);

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return json({ error: 'invalid_url' }, 400);
  }

  if (!IMAGE_HOST_ALLOWLIST.includes(parsed.hostname)) {
    return json({ error: 'host_not_allowed', host: parsed.hostname }, 400);
  }

  try {
    const resp = await fetch(target, {
      headers: { 'User-Agent': 'reading-log-proxy/1.0' },
    });
    const buf = await resp.arrayBuffer();
    return new Response(buf, {
      status: resp.status,
      headers: {
        ...CORS_HEADERS,
        'Content-Type': resp.headers.get('Content-Type') || 'image/jpeg',
        // 画像は書籍単位でほぼ不変なので長めキャッシュ (7 日)
        'Cache-Control': 'public, max-age=604800, immutable',
      },
    });
  } catch (err) {
    return json({ error: 'image_fetch_failed', message: String(err) }, 502);
  }
}

/// レスポンス JSON 中の楽天サムネイル URL を /image?url=... に書き換える。
/// JSON パース不要 (ホスト名を含む URL 文字列を正規表現で置換するだけ)。
function rewriteImageUrls(body, workerOrigin) {
  // "https://thumbnail.image.rakuten.co.jp/..." および ".../shop.r10s.jp/..." を対象。
  // JSON 内では URL がエスケープされて "https:\/\/..." になっているケースもあるので両対応。
  const pattern = /https?:(?:\/|\\\/)(?:\/|\\\/)(?:thumbnail\.image\.rakuten\.co\.jp|shop\.r10s\.jp)[^"\s]*/g;
  return body.replace(pattern, (match) => {
    // JSON エスケープを戻して素の URL を作る
    const raw = match.replace(/\\\//g, '/');
    const encoded = encodeURIComponent(raw);
    // 書き換え結果もエスケープ形式に合わせる (念のため / も raw のまま返す。JSON 的には / のエスケープは任意)
    return `${workerOrigin}/image?url=${encoded}`;
  });
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
