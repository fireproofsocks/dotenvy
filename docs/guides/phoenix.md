# Phoenix

This page shows you how to either generate a new Phoenix application using the [`dotenvy_generators` package](docs/reference/generators.md) OR how to retrofit the config files of an existing Phoenix app.

## Creating a new Phoenix application that uses Dotenvy

Make sure you have installed the [`dotenvy_generators`](docs/reference/generators.md) before continuing!

In a new terminal window, you can run the new task to generate a new Phoenix app, e.g. `mix phx.new.dotenvy hello`.  This should generate a functional Phoenix application that leverages `Dotenvy` for its configuration.

Have a look over the file structure: notice the `envs/` directory.  The files there house the values read at _runtime_, whereas the various config files inside of `config/` have been cleaned up so they focus on providing settings that must be defined at compile-time.

## Manually Editing Files

If you have an existing Phoenix application and you want to modify it to use `Dotenvy`, then you can reference the files below as a guideline for editing your configuration files.

Pay attention to how the files are organized: most of the configuration has been moved into the `runtime.exs` leaving only minimal bits in the env-specific compile-time configs. Remember that one of the guiding principles of `Dotenvy` is to use runtime configuration whenever possible.

> ### Replace the values to match your app {: .warning}
>
> You will need to replace `YourApp`, `YourAppWeb`, and `:your_app` with
> the appropriate modules and app name for _your application_. Don't just copy
> and paste these sample files -- make sure you don't overwrite any existing config
> for other apps/services that might not be present in this example.

### config/config.exs

```elixir
# config/config.exs
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :your_app,
  ecto_repos: [YourApp.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :your_app, YourAppWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: YourAppWeb.ErrorHTML, json: YourAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: YourApp.PubSub,
  live_view: [signing_salt: "xyz123AB"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  your_app: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  your_app: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger (compile-time config)
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
```

### config/dev.exs

```elixir
# config/dev.exs
import Config

# Compile-time configuration includes code_reloader, debug_errors, and force_ssl
# https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-compile-time-configuration
config :your_app, YourAppWeb.Endpoint,
  code_reloader: true,
  debug_errors: true,
  force_ssl: false,
  # Watch static and templates for browser reloading.
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/your_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ],
  # The watchers configuration can be used to run external
  # watchers to your application. For example, we can use it
  # to bundle .js and .css sources.
  # Watchers can be configured at runtime but are unlikely to change
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:your_app, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:your_app, ~w(--watch)]}
  ]

# Compile-time config
config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Enable dev routes for dashboard and mailbox (compile-time config)
config :your_app, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
```

### config/test.exs

```elixir
# config/test.exs
import Config

# Print only warnings and errors during test
config :logger, level: :warning
```

### config/prod.exs

```elixir
import Config

# Compile-time configuration includes code_reloader, debug_errors, and force_ssl
# https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-compile-time-configuration
config :your_app, YourAppWeb.Endpoint,
  code_reloader: false,
  debug_errors: false,
  force_ssl: false

# Do not print debug messages in production
config :logger, level: :info
```

### config/runtime.exs

```elixir
# config/runtime.exs
import Config
import Dotenvy

# For local development, read dotenv files inside the envs/ dir;
# for releases, read them at the RELEASE_ROOT
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/")

source!(
  [
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    System.get_env()
  ],
  require_files: [Path.absname(".env", env_dir_prefix)]
)


# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts. Do not define any compile-time configuration in here,
# as it won't be applied.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/your_app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if env!("PHX_SERVER", :boolean!) do
  config :your_app, YourAppWeb.Endpoint, server: true
end

# Initialize plugs at runtime for faster development compilation
# values can be :runtime or :compile; must be :compile in prod (the default)
config :phoenix, :plug_init_mode, env!("PHX_PLUGIN_INIT_MODE", :existing_atom!)

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

ip =
  env!("HTTP_INTERFACE", fn val ->
    with [_] <- String.split(val, "."),
         [_] <- String.split(val, ":") do
      raise "Invalid IP address specified"
    else
      parts -> parts |> Enum.map(&String.to_integer/1) |> List.to_tuple()
    end
  end)

ecto_socket_options = if env!("ECTO_IPV6", :boolean!), do: [:inet6], else: []

config :your_app, YourApp.Repo,
  # ssl: true,
  url: env!("DATABASE_URL", :string!),
  pool: env!("PG_POOL", :module?),
  pool_size: env!("POOL_SIZE", :integer!),
  socket_options: ecto_socket_options,
  stacktrace: env!("ECTO_STACKTRACE", :boolean),
  show_sensitive_data_on_connection_error:
    env!("SHOW_SENSITIVE_DATA_ON_CONNECTION_ERROR", :boolean)

if env!("ENABLE_DISTRIBUTED_MODE", :boolean) do
  config :your_app, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string)
end

config :your_app, YourAppWeb.Endpoint,
  cache_static_manifest: env!("PHX_CACHE_STATIC_MANIFEST", :string?),
  check_origin: env!("HTTP_CHECK_ORIGIN", :boolean),
  http: [ip: ip, port: env!("PORT", :integer!)],
  secret_key_base: env!("SECRET_KEY_BASE", :string!),
  # Used to build URLs
  url: [
    host: env!("PHX_HOST", :string!),
    port: env!("PHX_URL_PORT", :integer!),
    scheme: env!("PHX_URL_SCHEME", :string!)
  ]

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to your endpoint configuration:
#
#     config :your_app, YourAppWeb.Endpoint,
#       https: [
#         ...,
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your config/prod.exs,
# ensuring no data is ever sent via http, always redirecting to https:
#
#     config :your_app, YourAppWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# ## Configuring the mailer
#
# In production you need to configure the mailer to use a different adapter.
# Also, you may need to configure the Swoosh API client of your choice if you
# are not using SMTP. Here is an example of the configuration:
#
#     config :your_app, YourApp.Mailer,
#       adapter: Swoosh.Adapters.Mailgun,
#       api_key: System.get_env("MAILGUN_API_KEY"),
#       domain: System.get_env("MAILGUN_DOMAIN")
#
# For this example you need include a HTTP client required by Swoosh API client.
# Swoosh supports Hackney and Finch out of the box:
#
#     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
#
# See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
# Configures Swoosh API Client
if env!("SWOOSH_API_CLIENT", :boolean) do
  config :swoosh, api_client: env!("SWOOSH_API_CLIENT", :module!), finch_name: YourApp.Finch
else
  config :swoosh, api_client: false
end

config :your_app, YourApp.Mailer, adapter: env!("SWOOSH_MAILER_ADAPTER", :module)
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: YourApp.Finch
config :swoosh, local: env!("SWOOSH_LOCAL_MEMORY_STORAGE", :boolean)
```

### envs/.env

The shared/default values can be listed and documented here.  The `.dev.env` and other `.env` files can either copy this file in its entirety and modify the values (for easier diff comparisons), or they can include only the variables that they need to change.

```env
# envs/.env (default/shared config)
# ###################
# Distributed Node  #
# ###################
# If distributed mode is enabled, the DNS_CLUSTER_QUERY variable must have a value
ENABLE_DISTRIBUTED_MODE=false
DNS_CLUSTER_QUERY=

# #####################
# Phoenix / Webserver #
# #####################
# The interface(s) to listen on.
# Can be specified as the following formats:
# `1.2.3.4` for IPv4 addresses (using period separators)
# `1:2:3:4:5:6:7:8` for IPv6 addresses (using colon separators)
# 
# To bind to loopback IPv4 address & prevent access from other machines: `127.0.0.1`
# To allow access from other machines: `0.0.0.0`
# 
# To enable IPv6 and bind on all interfaces: `0:0:0:0:0:0:0:0`
# For local network only access: `0:0:0:0:0:0:0:1`
# 
# See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
# for details about using IPv6 vs IPv4 and loopback vs public addresses.
HTTP_INTERFACE=127.0.0.1
HTTP_CHECK_ORIGIN=false
# Port where HTTP requests will be accepted
PORT=4000
# A secret key used as a base to generate secrets for encrypting and signing data. 
# For example, cookies and tokens are signed by default, but they may also be 
# encrypted if desired. Must be set per application.
SECRET_KEY_BASE=
# Boolean indicating whether to start the Phoenix webserver implicitly.
# Usually this is false for dev and true for prod
PHX_SERVER=false
# PHX_HOST, PHX_URL_PORT, and PHX_URL_SCHEME are used to create links
PHX_HOST=localhost
# Duplicate the ${PORT} value for http; 443 recommended for https
PHX_URL_PORT=
# scheme may be either http or https
PHX_URL_SCHEME=http
# Specifies the path to a cache manifes containing the digested version of 
# static files. This manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
# Leave empty for dev or when you do not need a manifest
PHX_CACHE_STATIC_MANIFEST=
# Set a higher stacktrace during development, e.g. 20, or set to false to disable.
# Disabling is recommended in prod as building large stacktraces may be expensive.
PHX_STACKTRACE_DEPTH=20
# Initialize plugs at runtime for faster development compilation
# values can be :runtime or :compile; must be :compile in prod (the default)
PHX_PLUGIN_INIT_MODE=compile

############
# Database #
############
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
MIX_TEST_PARTITION=
PG_USERNAME=postgres
PG_PASSWORD=postgres
PG_HOSTNAME=localhost
PG_DATABASE=your_app_dev
PG_POOL=DBConnection.ConnectionPool
POOL_SIZE=10
# DATABASE_URL format is `ecto://USER:PASS@HOST/DATABASE`
DATABASE_URL=ecto://${PG_USERNAME}:${PG_PASSWORD}@${PG_HOSTNAME}/${PG_DATABASE}
SHOW_SENSITIVE_DATA_ON_CONNECTION_ERROR=true
ECTO_IPV6=false
ECTO_STACKTRACE=true

###################
# Swoosh / Mailer #
###################
# Specify a module as a Swoosh API client for production adapters or set to false
# to disable. See https://hexdocs.pm/swoosh/Swoosh.ApiClient.html
SWOOSH_API_CLIENT=false
SWOOSH_LOCAL_MEMORY_STORAGE=true
# By default it uses the Swoosh.Adapters.Local adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
# For production it's recommended to configure a different adapter
SWOOSH_MAILER_ADAPTER=Swoosh.Adapters.Local
```

### envs/.dev.env

```env
# envs/.dev.env
HTTP_INTERFACE=127.0.0.1
HTTP_CHECK_ORIGIN=false
PORT=4000
SECRET_KEY_BASE=6D1kPrXseBg9F1O9cZUd8ocIH7l3OgT9ZlopIXqDr+jYjNrcvbjqwNvzHPKIakcF
PHX_URL_PORT=${PORT}
PHX_PLUGIN_INIT_MODE=runtime

PG_USERNAME=postgres
PG_PASSWORD=postgres
PG_HOSTNAME=localhost
PG_DATABASE=your_app_dev
PG_POOL=DBConnection.ConnectionPool
POOL_SIZE=10
# DATABASE_URL format is `ecto://USER:PASS@HOST/DATABASE`
DATABASE_URL=ecto://${PG_USERNAME}:${PG_PASSWORD}@${PG_HOSTNAME}/${PG_DATABASE}
SHOW_SENSITIVE_DATA_ON_CONNECTION_ERROR=true
ECTO_IPV6=false
ECTO_STACKTRACE=true
```

### envs/.test.env

```env
# envs/.test.env
HTTP_INTERFACE=127.0.0.1
HTTP_CHECK_ORIGIN=false
PORT=4002
SECRET_KEY_BASE=514niO7SLGRKi01EN1fQUqekoyfHSQL0640m64tAkJSPG7anLA6iPxWrcIUzCgyA
PHX_URL_PORT=${PORT}
PHX_PLUGIN_INIT_MODE=runtime

PG_USERNAME=postgres
PG_PASSWORD=postgres
PG_HOSTNAME=localhost
PG_DATABASE=your_app_test
PG_POOL=Ecto.Adapters.SQL.Sandbox
POOL_SIZE=10
# DATABASE_URL format is `ecto://USER:PASS@HOST/DATABASE`
DATABASE_URL=ecto://${PG_USERNAME}:${PG_PASSWORD}@${PG_HOSTNAME}/${PG_DATABASE}
SHOW_SENSITIVE_DATA_ON_CONNECTION_ERROR=true
ECTO_IPV6=false
ECTO_STACKTRACE=true

SWOOSH_MAILER_ADAPTER=Swoosh.Adapters.Test
```

### envs/.prod.env

In prod, you may have certain env variables provided by your host.  For example. [Fly.io](https://fly.io/) will define a number of env variables for you. It can be helpful to list them in your `.prod.env` file as a reminder.

```env
# envs/.prod.env
ENABLE_DISTRIBUTED_MODE=true
# DNS_CLUSTER_QUERY= # set by Fly.io

HTTP_INTERFACE=0:0:0:0:0:0:0:0
HTTP_CHECK_ORIGIN=true
# PORT= # set by Fly.io
# SECRET_KEY_BASE= # Set by Fly.io
PHX_SERVER=true
PHX_HOST=your-app-website.com
PHX_URL_PORT=443
PHX_URL_SCHEME=https
PHX_CACHE_STATIC_MANIFEST=priv/static/cache_manifest.json
PHX_STACKTRACE_DEPTH=false
PHX_PLUGIN_INIT_MODE=compile

# DATABASE_URL= # set by Fly.io
SHOW_SENSITIVE_DATA_ON_CONNECTION_ERROR=false
ECTO_IPV6=true
ECTO_STACKTRACE=false

SWOOSH_API_CLIENT=Swoosh.ApiClient.Finch
SWOOSH_LOCAL_MEMORY_STORAGE=false
# For production it's recommended to configure a different adapter...
# SWOOSH_MAILER_ADAPTER=Swoosh.Adapters.Local
```
