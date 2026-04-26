# internal/handler

## 役割

- HTTP request を受けて response を返す。
- feature ごとの画面・API の振る舞いを `handler/<feature>/<action>/` に閉じ込める。
- 複雑な処理は `Handler`, `Usecase`, `Result`, `Formatter` に分ける。
- Inertia 向けの HTTP response 変換は adapter に寄せ、feature handler では page / action の結果だけを返す。

## ディレクトリ構成

- 基本は `handler/<feature>/<action>/` とする。例: `handler/top/show/`
- 画面表示系で複数の domain object を束ねるなら、少なくとも次を分ける。
  - `*_handler.go`
  - `*_usecase.go`
  - `*_result.go`
  - `*_formatter.go`
- 単純な health check のように責務が 1 つなら 1 ファイルでもよい。
- notfound のように repository access がなく、props 変換もほぼ不要な画面は `Handler` 単体でもよい。

## 画面 handler の基準

- 画面表示系 handler は、既存の `top/show`, `article/search`, `article/show`, `admin/show` の責務分割を基準にする。
- 基本は `*_handler.go`, `*_usecase.go`, `*_formatter.go` に分ける。query parse がある画面は `*_request.go` も置く。
- result struct は小さいなら `*_usecase.go` に置いてよい。formatter の入力を安定させるため、handler で props を組み立てない。

- `Handler`
  - HTTP の入口
  - path/query parse と validation
  - usecase の呼び出し
  - page/action の result と error の返却
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

- feature handler は `type Handler struct { usecase *Usecase }` を基本形にする。
- `NewHandler(usecase)` で依存を受け取る。
- 公開入口は `Handle(r)` に揃える。
- route から直接 package 関数を呼ばず、`internal/di/container.go` で `NewHandler(...)` した instance を使う。
- `Handle` の中では次だけを行う。
  - request parse / validation
  - `h.usecase.run...(ctx, input)` の呼び出し
  - `handlerresult.Page(...)` または `handlerresult.Redirect(...)` と `error` の返却
- handler に repository 呼び出し、検索条件の分岐、props の map 組み立てを持ち込まない。
- query validation がある画面は `toInput` と parse helper を `*_request.go` に置く。
- query validation は `*handlererror.ValidationError` を返し、page handler は最後にそのまま `error` として返す。
- Inertia の lazy props を使う画面でも、props 自体は handler で `gonertia.Props` を組み立て、partial reload の分岐だけを持つ。
- `initial` は partial reload する画面でだけ使う。partial reload しない画面は `format(result) gonertia.Props` で props を直に返す。
- notfound のようにロジックが薄い画面は `Handler` 単体で十分なことがある。
- その場合でも、既存 project が `Handler` struct と `container` 経由で揃えているなら、その流儀に合わせる。
- `RenderWithStatus` を使う画面でも、可能なら adapter の外へ `http.ResponseWriter` を漏らさない。

## Adapter の基準

- page 用 adapter は `func(*http.Request) (handlerresult.PageResult, error)` を受ける。
- action 用 adapter は `func(*http.Request) (handlerresult.ActionResult, error)` を受ける。
- `HandlerResult` のような共通 interface は置かず、page/action で返り値型を分ける。
- adapter が行うのは次に限る。
  - `PageResult` から Inertia render
  - `ActionResult.RedirectTo` から redirect
  - `ValidationError` / `DisplayableError` の解釈
  - session の flash / validation error の保存と復元
- action の validation error は adapter が session に保存して redirect back する。
- page の validation error は adapter が `validationErrors` props に載せて通常の page render に流す。

## Usecase の書き方

- `Usecase` は必要な repository interface を field に持つ struct にする。
- 依存先は domain の repository interface に限定する。
- `run(ctx)` / `runPartialSearch(ctx, input)` など action に合う入口を置き、feature の取得条件を明示して result struct を返す。
- POST などの mutation でも、handler は request parse / response に留め、repository 呼び出しや対象存在確認は usecase に置く。
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
- 一覧・検索画面は `formatInitial` と `formatPartialSearch` のように props 単位で分ける。
- `formatInitial` は partial reload 用の props 分割が必要な場合だけ使う。
- 詳細画面やトップ画面は `format(result)` でまとめてよい。

## 実装順

1. `*_usecase.go` で result/input struct と repository interface を受け取る `Usecase` を書く。
2. query がある画面は `*_request.go` で request parse / validation を書く。
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
	usecase *Usecase
}

func NewHandler(u *Usecase) *Handler {
	return &Handler{usecase: u}
}

func (h *Handler) Handle(r *http.Request) (handlerresult.PageResult, error) {
	result, err := h.usecase.Run(r.Context())
	if err != nil {
		return handlerresult.PageResult{}, err
	}
	return handlerresult.Page("PageName", Format(result)), nil
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
	latestArticles := make(gonertia.props, 0, len(result.LatestArticles))
	for _, article := range result.LatestArticles {
		categoryNames := make([]string, 0, len(article.Categories))
		for _, category := range article.Categories {
			categoryNames = append(categoryNames, category.Name)
		}
		latestArticles = append(latestArticles, gonertia.props{
			"id":            article.ID,
			"title":         article.Title,
			"date":          article.UpdatedAt.Format(time.RFC3339),
			"categoryNames": categoryNames,
		})
	}

	categories := make(gonertia.props, 0, len(result.Categories))
	for _, category := range result.Categories {
		categories = append(categories, gonertia.props{
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
- 検索画面では、query の文字列 parse と validation は request、カテゴリIDの正規化や page/perPage の検索条件化は usecase に寄せる。
- not found と validation error と internal error の扱いを既存 route と揃える。
- `ValidationError` は例外扱いではなく通常の `error` として返し、adapter 側で page/action に応じた response へ変換する。
- `toInput` は query parse 後の `input` と `*handlererror.ValidationError` を返す形を基本にする。
- not found を表すためだけに repository に `Find` を足さず、既存の `Search` / `Paginate` で条件取得できるならそちらを使う。
- handler が肥大化したら、まず usecase か formatter に責務を逃がす。
- formatter が複雑になっても、repository 呼び出しや domain mutation は入れない。

## Handler テスト

- integration test では、HTTP サーバー初期化と DB 初期化は `internal/test/` に寄せ、個別 test は seed と期待値に集中させる。
- Inertia の画面 test では、共通の request helper と response helper を `internal/test/helper/` に置き、各 test で request 構築や JSON decode を繰り返さない。
- Inertia response の検証は、status code / component / props をまとめて検証する helper か method に寄せる。
- props 全体を struct 化しにくい場合は、typed struct より JSON 比較や `gonertia.props` 比較を優先してよい。
- fixture は `internal/test/fixture/<entity>/` に置き、位置引数が増えるなら入力 struct を定義して可読性を保つ。
