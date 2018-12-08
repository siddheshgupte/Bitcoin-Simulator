# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :proj4_server, Proj4ServerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "UVEkdA5ZL0X0Gsvn1Sa66qXIXCUU71CCbsyVIBAlgaoxBg9XA+yIJt2msT8+t/IY",
  render_errors: [view: Proj4ServerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Proj4Server.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
