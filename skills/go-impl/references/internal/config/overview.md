# internal/config

## 役割

- 環境変数や secret の読み出しを 1 箇所に寄せる。
- 呼び出し側には `MustGet...` 系関数を公開して、起動時に設定不備を落とす。
- env や secret の文字列を domain 型へ変換する入口にもする。

## パターン

- 生の `os.Getenv` や secret 読み出しを他 package に散らさない。
- enum 的な値は `domain` 側の parse 関数へ渡して型に変換する。
- 取得元ごとに helper を分ける。例: env 用、secret 用。
- secret の実体パスや env 名は `config` で隠蔽し、呼び出し側は `MustGetAdminBasicAuthUser()` のような関数だけを見る。
- `config` は値の解釈までは行ってよいが、依存生成や業務ロジックは持たせない。

## コード例

```go
func MustGetAppEnv() domain.AppEnv {
	raw := mustGetEnvString("APP_ENV")
	appEnv, err := domain.ParseAppEnv(raw)
	if err != nil {
		log.Fatal(err)
	}
	return appEnv
}

func MustGetAdminBasicAuthUser() string {
	return mustGetSecretString("admin_basic_auth_user")
}
```

## 注意点

- `config` は値の取得に集中し、業務ロジックを持たせない。
- secret 名や env 名は呼び出し側で組み立てず、この層で隠蔽する。
- `MustGet...` が増えるときは、呼び出し側の用途別に揃える。例: `MustGetPort`, `MustGetSSRURL`, `MustGetTemplateAppScriptSrc`
