# cmd/main.go

## 役割

- config から起動時設定を読む
- Inertia や template data の初期化を行う
- DB client など外部依存を生成し、`defer` で close する
- `di.Container` を生成する
- `http.ServeMux` に route を登録する
- middleware をまとめて適用する
- `ListenAndServe` で起動する

## パターン

- 起動に必要な値は `config.MustGet...` で取得する。
- 外部リソースは `main` で open/close する。
- `di.NewContainer(...)` には open 済みの依存を渡す。
- route 群は `setup...Routes` のような関数へ分ける。
- route 登録関数には必要なら `*di.Container` を渡し、その中で `container.SomeHandler()` を使う。
- path parameter の parse は route 登録箇所または薄い handler 入口で行う。
- parse 失敗時の応答は既存方針に揃える。

## コード例

```go
func main() {
	appEnv := config.MustGetAppEnv()
	port := config.MustGetPort()
	ssrURL := config.MustGetSSRURL()
	rootTemplate := config.MustGetInertiaRootTemplate()

	inertiaApp, err := gonertia.NewFromFile(rootTemplate, gonertia.WithSSR(ssrURL))
	if err != nil {
		log.Fatal(err)
	}
	configureTemplateAssets(appEnv, inertiaApp)

	entClient, err := db.OpenEntClient()
	if err != nil {
		log.Fatal(err)
	}
	defer entClient.Close()

	container := di.NewContainer(entClient, inertiaApp)

	mux := http.NewServeMux()
	setupRootRoutes(mux, inertiaApp, container)

	handler := middleware.Chain(
		http.NewCrossOriginProtection().Handler(mux),
		middleware.NormalizePath(),
	)

	log.Fatal(http.ListenAndServe(":"+port, handler))
}
```

## 注意点

- middleware の適用順は挙動に直結するので既存順を崩さない。
- resource close は `main` に集約し、`di` に持ち込まない。
- 依存注入は interface で受けられる形を優先する。
- 新しい管理系 route を足すときは認証 middleware の適用漏れを防ぐ。
