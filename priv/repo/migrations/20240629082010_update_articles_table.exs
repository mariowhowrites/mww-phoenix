defmodule MwwPhoenix.Repo.Migrations.UpdateArticlesTable do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :notion_id, :string
      add :description, :text
      add :category, :string
      add :slug, :string
      add :image, :string
      add :published, :boolean
      add :published_dev, :boolean
      add :date, :string
      add :tags, {:array, :string}

      modify :content, :text
    end

    create index(:articles, [:notion_id], unique: true)
  end
end
