# internal/middleware

## 役割

- `func(http.Handler) http.Handler` を共通化して扱う
- route へまとめて適用しやすくする
- path 正規化や認証のような HTTP 横断処理を一箇所に寄せる

## パターン

- `type Middleware func(http.Handler) http.Handler` を基準にする。
- `Chain` で逆順適用し、宣言順と実行順の見通しを保つ。
- 認証付き route 群には `HandleWith` のような helper を使うと漏れを防ぎやすい。
- route 単位のラップと route 群まとめ適用の両方をサポートすると、`/admin` のような保護領域を扱いやすい。

## コード例

```go
type Middleware func(http.Handler) http.Handler

func Chain(handler http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		handler = middlewares[i](handler)
	}
	return handler
}

func HandleWith(mux *http.ServeMux, middlewares ...Middleware) func(string, http.Handler) {
	return func(pattern string, handler http.Handler) {
		mux.Handle(pattern, Chain(handler, middlewares...))
	}
}
```

## 注意点

- path 正規化、認証、CORS/CSRF 系は順序依存がある。
- middleware で業務知識を持ち込みすぎない。
- middleware の中で domain や repository に依存し始めたら責務過多を疑う。
