# internal/handler

## 役割

- HTTP request を受けて response を返す。
- feature ごとの画面・API の振る舞いを `handler/<feature>/<action>/` に閉じ込める。
- 複雑な処理は `Handler`, `Usecase`, `Result`, `Formatter` に分ける。

## ディレクトリ構成

- 基本は `handler/<feature>/<action>/` とする。例: `handler/top/show/`
- 画面表示系で複数の domain object を束ねるなら、少なくとも次を分ける。
  - `*_handler.go`
  - `*_usecase.go`
  - `*_result.go`
  - `*_formatter.go`
- 単純な health check のように責務が 1 つなら 1 ファイルでもよい。
- notfound のように repository access がなく、props 変換もほぼ不要な画面は `Handler` 単体でもよい。

## `top/show` を基準にした分割

- 画面表示系 handler の再実装は、`internal/handler/feature/top/show/` 一式を基準に考える。
- 基準にするのは `show_top_handler.go` 単体ではなく、次の 4 ファイルの責務分割。
  - `show_top_handler.go`
  - `show_top_usecase.go`
  - `show_top_result.go`
  - `show_top_formatter.go`
- まず `top/show` と同じ責務境界を置き、そのうえで不要な層だけ省く。

- `Handler`
  - HTTP の入口
  - `usecase.Run(ctx)` の呼び出し
  - error を HTTP status に変換
  - `Render(..., Format(result))` の呼び出し
- `Usecase`
  - repository interface の呼び出し
  - query criteria や order の決定
  - 画面が必要とする domain object を result struct に詰めて返す
- `Result`
  - usecase の返り値
  - 画面が必要とする複数の domain object を 1 つにまとめる
- `Formatter`
  - result を frontend props に変換
  - 日時整形、配列の組み替え、表示専用 field の導出

## Handler の書き方

- `type Handler struct { inertia *gonertia.Inertia; usecase *Usecase }` を基本形にする。
- `NewHandler(inertiaApp, usecase)` で依存を受け取る。
- 公開入口は `Handle(w, r)` に揃える。
- route から直接 package 関数を呼ばず、`internal/di/container.go` で `NewHandler(...)` した instance を使う。
- `Handle` の中では次だけを行う。
  - `result, err := h.usecase.Run(r.Context())`
  - error 時の `http.Error(...)`
  - 成功時の `h.inertia.Render(w, r, "<PageName>", Format(result))`
- handler に repository 呼び出し、検索条件の分岐、props の map 組み立てを持ち込まない。
- notfound のようにロジックが薄い画面は `Handler` 単体で十分なことがある。
- その場合でも、既存 project が `Handler` struct と `container` 経由で揃えているなら、その流儀に合わせる。
- `RenderWithStatus` を使う画面でも、可能なら `Handle(w, r)` を持つ `Handler` struct に閉じ込める。

## Usecase の書き方

- `Usecase` は必要な repository interface を field に持つ struct にする。
- 依存先は domain の repository interface に限定する。
- `Run(ctx)` は feature の取得条件を明示して、result struct を返す。
- top page 相当なら次の流れにする。
  - `articleRepository.Search(ctx, article.SearchArticleCriteria{Limit: 10, OrderBy: article.OrderByLatest})`
  - `categoryRepository.All(ctx, category.OrderByNameAsc)`
  - 取得結果を `ShowTopResult{LatestArticles: ..., Categories: ...}` に詰める
- usecase は HTTP や Inertia に依存させない。

## Result の書き方

- `ShowTopResult` のように feature ごとの result struct を定義する。
- field は frontend props ではなく domain object ベースで持つ。
- top page なら次のようにする。

```go
type ShowTopResult struct {
	LatestArticles []article.Article
	Categories     []category.Category
}
```

- formatter の入力を安定させるため、usecase が返す値はここに集約する。

## Formatter の書き方

- `Format(result)` は result から `gonertia.Props` を返す関数にする。
- formatter では表示用の変換だけを行う。
  - `UpdatedAt.Format(time.RFC3339)`
  - `Categories` から `categoryNames []string` を作る
  - frontend が必要な key 名に詰め替える
- formatter で repository access や validation をしない。
- domain object をそのまま view に晒さず、props で必要な形に落とし切る。

## 実装順

1. `*_result.go` で result struct を定義する。
2. `*_usecase.go` で repository interface を受け取る `Usecase` と `Run(ctx)` を書く。
3. `*_formatter.go` で result から props への変換を書く。
4. `*_handler.go` で `Handle(w, r)` を書く。
5. `internal/di/container.go` で `NewUsecase(...)` と `NewHandler(...)` をつなぐ。
6. `cmd/app/main.go` の route から `container.SomeHandler().Handle` を呼ぶ。

## 層を省略してよい条件

- まずは `top/show` と同じ 4 分割を基準に考える。
- 次の両方を満たすときだけ、`Usecase` / `Result` / `Formatter` の一部省略を検討してよい。
  - repository access や query 条件の決定がない
  - props 変換が実質的に不要か、固定値だけで終わる
- ただし `Handler` struct と `internal/di/container.go` での組み立ては基本的に維持する。
- 既存 feature が同じ種類の画面をどう実装しているかを優先し、簡略化を先に選ばない。
- notfound のように処理が `RenderWithStatus(...)` だけで閉じるなら、`Handler` だけを実装し、`Usecase` / `Result` / `Formatter` は作らなくてよい。

## 再実装用の最小テンプレート

```go
type Handler struct {
	inertia *gonertia.Inertia
	usecase *Usecase
}

func NewHandler(i *gonertia.Inertia, u *Usecase) *Handler {
	return &Handler{inertia: i, usecase: u}
}

func (h *Handler) Handle(w http.ResponseWriter, r *http.Request) {
	result, err := h.usecase.Run(r.Context())
	if err != nil {
		http.Error(w, "取得エラー", http.StatusInternalServerError)
		return
	}
	if err := h.inertia.Render(w, r, "PageName", Format(result)); err != nil {
		http.Error(w, "描画エラー", http.StatusInternalServerError)
	}
}
```

```go
type Usecase struct {
	articleRepository  article.ArticleRepository
	categoryRepository category.CategoryRepository
}

func NewUsecase(
	articleRepository article.ArticleRepository,
	categoryRepository category.CategoryRepository,
) *Usecase {
	return &Usecase{
		articleRepository:  articleRepository,
		categoryRepository: categoryRepository,
	}
}

func (u *Usecase) Run(ctx context.Context) (ShowTopResult, error) {
	articles, err := u.articleRepository.Search(ctx, article.SearchArticleCriteria{
		Limit:   10,
		OrderBy: article.OrderByLatest,
	})
	if err != nil {
		return ShowTopResult{}, err
	}

	categories, err := u.categoryRepository.All(ctx, category.OrderByNameAsc)
	if err != nil {
		return ShowTopResult{}, err
	}

	return ShowTopResult{
		LatestArticles: articles,
		Categories:     categories,
	}, nil
}
```

```go
func Format(result ShowTopResult) gonertia.Props {
	latestArticles := make([]map[string]any, 0, len(result.LatestArticles))
	for _, article := range result.LatestArticles {
		categoryNames := make([]string, 0, len(article.Categories))
		for _, category := range article.Categories {
			categoryNames = append(categoryNames, category.Name)
		}
		latestArticles = append(latestArticles, map[string]any{
			"id":            article.ID,
			"title":         article.Title,
			"date":          article.UpdatedAt.Format(time.RFC3339),
			"categoryNames": categoryNames,
		})
	}

	categories := make([]map[string]any, 0, len(result.Categories))
	for _, category := range result.Categories {
		categories = append(categories, map[string]any{
			"id":   category.ID,
			"name": category.Name,
		})
	}

	return gonertia.Props{
		"latestArticles": latestArticles,
		"categories":     categories,
	}
}
```

## 注意点

- path/query の parse は handler 境界で済ませ、domain には型付きで渡す。
- not found と validation error と internal error の扱いを既存 route と揃える。
- handler が肥大化したら、まず usecase か formatter に責務を逃がす。
- formatter が複雑になっても、repository 呼び出しや domain mutation は入れない。

## Handler テスト

- integration test では、HTTP サーバー初期化と DB 初期化は `internal/test/` に寄せ、個別 test は seed と期待値に集中させる。
- Inertia の画面 test では、共通の request helper と response helper を `internal/test/helper/` に置き、各 test で request 構築や JSON decode を繰り返さない。
- Inertia response の検証は、status code / component / props をまとめて検証する helper か method に寄せる。
- props 全体を struct 化しにくい場合は、typed struct より JSON 比較や `map[string]any` 比較を優先してよい。
- fixture は `internal/test/fixture/<entity>/` に置き、位置引数が増えるなら入力 struct を定義して可読性を保つ。
