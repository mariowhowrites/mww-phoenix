defmodule MwwPhoenix.Repo do
  use Ecto.Repo,
    otp_app: :mww_phoenix,
    adapter: Ecto.Adapters.Postgres
end
