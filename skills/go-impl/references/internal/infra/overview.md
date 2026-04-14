# internal/infra

## 役割

- domain の repository interface を実装する
- DB、外部 API、ファイル I/O などの詳細を閉じ込める
- 永続化モデルから domain object への変換を担う

## パターン

- package は `infra/<feature>` として切る。
- 実装 struct は `Repository` など単純な名前にし、`New...Repository` を公開する。
- repository struct は `*ent.Client` など外部 client を field に持つ。
- domain の validate を呼べる入力は、保存前または更新前に確認する。
- 検索条件がある場合は `criteria` の各項目で段階的に絞り込む。
- 並び順は domain の `OrderBy` を switch で解釈し、未対応値は error にする。
- `ent` など永続化モデルは hydrator で domain 型へ変換して返す。

## コード例

```go
type ArticleRepository struct {
	client *ent.Client
}

func NewArticleRepository(client *ent.Client) *ArticleRepository {
	return &ArticleRepository{client: client}
}

func (r *ArticleRepository) Search(ctx context.Context, criteria domainArticle.SearchArticleCriteria) ([]domainArticle.Article, error) {
	query := r.client.Article.Query().WithCategories()

	if criteria.Title != "" {
		query.Where(entArticle.TitleContainsFold(criteria.Title))
	}

	switch criteria.OrderBy {
	case domainArticle.OrderByLatest:
		query.Order(ent.Desc(entArticle.FieldUpdatedAt))
	default:
		return nil, fmt.Errorf("unsupported order: %s", criteria.OrderBy)
	}

	if criteria.Limit > 0 {
		query.Limit(criteria.Limit)
	}

	models, err := query.All(ctx)
	if err != nil {
		return nil, err
	}
	return hydrateArticles(models), nil
}
```

## Hydrator

- `hydrateArticle(model *ent.Article) domainArticle.Article` のような private 関数で 1 件変換する。
- slice は `hydrateArticles(models []*ent.Article)` のような helper でまとめて変換する。
- field mapping に専念し、repository access や validation は持たせない。
- edge から別 entity を読むときは、対応する infra package の hydrator を再利用する。

## 注意点

- domain 型を返す責務は infra にある。
- handler 都合の struct を infra で返さない。
- 永続化ライブラリの型を handler や domain へ漏らさない。
