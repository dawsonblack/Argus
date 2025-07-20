defmodule Argus.Slugger do
  def maybe_generate_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = changeset) do
    slug = Slug.slugify(name)
    Ecto.Changeset.put_change(changeset, :slug, slug)
  end

  def maybe_generate_slug(changeset), do: changeset
end
