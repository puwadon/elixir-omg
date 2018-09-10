use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :omg_watcher, OMG.Watcher.Web.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [],
  server: true

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# command from your terminal:
#
#     openssl req -new -newkey rsa:4096 -days 365 -nodes -x509
#             -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
#             -keyout priv/server.key -out priv/server.pem
#
# The `http:` config above can be replaced with:
#
#     https: [port: 4000, keyfile: "priv/server.key", certfile: "priv/server.pem"],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Do not include metadata nor timestamps in development logs

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :omg_watcher, OMG.Watcher.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "omisego_dev",
  password: "omisego_dev",
  database: "omisego_dev",
  hostname: "localhost",
  pool_size: 10

# TODO: these two are here to ensure swifter sync in `:dev` env, and are geared towards a 1-sec root chain block
#       interval. They are taken to be equal to the `:test` env.
#       Rethink properly the semantics of root chain coordinator
config :omg_watcher,
  block_getter_height_sync_interval_ms: 20

config :omg_api,
  rootchain_height_sync_interval_ms: 20
