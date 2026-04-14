# internal/domain

## 役割

- エンティティ本体
- ID 型と parse 関数
- 作成入力や検索条件
- repository interface
- 並び順や enum 的な値を表す型

## パターン

- feature ごとに package を切る。例: `domain/article`, `domain/category`
- `Entity.Validate()` で entity 自体の整合性を確認する。
- `Create<Entity>Input.Validate()` で作成入力の必須項目を確認する。
- 共通の必須チェックは `validateContent` のような private helper に寄せる。
- ID 型は `type <Entity>ID uint32` や `string` など project に合う実体型を使い、`Parse<Entity>ID` を置く。
- `Search<Entity>Criteria` は検索で受ける条件だけを持つ。
- `OrderBy` のような並び順は DB カラム名を直接持たず、domain の型で表現する。
- `repository interface` は domain に置く。
- repository のメソッド引数と返り値は domain 型だけにする。

## コード例

```go
type Article struct {
	ID    ArticleID
	Title string
}

type CreateArticleInput struct {
	Title string
}

func (a CreateArticleInput) Validate() error {
	return validateContent(a.Title)
}

type OrderBy string

const (
	OrderByLatest OrderBy = "latest"
)

type SearchArticleCriteria struct {
	Title   string
	Limit   int
	OrderBy OrderBy
}

type ArticleRepository interface {
	Search(ctx context.Context, criteria SearchArticleCriteria) ([]Article, error)
	Create(ctx context.Context, input CreateArticleInput) (Article, error)
}
```

## 注意点

- domain は HTTP や DB に依存させない。
- validation は project 固有の表示文言より、型の整合性を優先して保つ。
- entity と input の責務を混ぜない。
- hydrate 時に毎回 validation を掛ける前提にはしない。通常は入力時 validation を優先する。
