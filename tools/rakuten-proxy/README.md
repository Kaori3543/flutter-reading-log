# reading-log-rakuten-proxy

Cloudflare Worker が Flutter Web / モバイル向けに楽天 Books API を CORS 対応で中継する。

## エンドポイント

- `GET /books/search?title=...&hits=20&sort=sales` → BooksBook/Search
- `GET /books/genre?booksGenreId=...` → BooksGenre/Search

Worker 側で applicationId / accessKey を差し込む。クライアントは Key を持たなくてよい。

## 初回セットアップ

```powershell
# ログイン (既に済んでいれば不要)
wrangler login

# Secret を登録 (対話式で値を入力)
wrangler secret put RAKUTEN_APP_ID
wrangler secret put RAKUTEN_ACCESS_KEY

# デプロイ
wrangler deploy
```

デプロイ後、`https://reading-log-rakuten-proxy.<subdomain>.workers.dev` の URL が発行される。

## ローカル開発

```powershell
wrangler dev
```

`http://localhost:8787` で開発サーバが立つ。
