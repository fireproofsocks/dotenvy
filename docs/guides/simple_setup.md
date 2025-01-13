# Simple Setup

Here is another demonstration of how you can configure your app for maximum simplicity.  In this example, we will abolish the `dev.ex`, `prod.exs`, and `test.exs` and leave _only_ the compile-time config (`config/config.exs`) and the runtime configuration (`config/runtime.exs`).

See the [article](https://fireproofsocks.medium.com/configuration-in-elixir-with-dotenvy-8b20f227fc0e) about using `Dotenvy` in your application for more discussion on this and other approaches.

To try this out, we can use the `dot.new` generator to generate a new application and then delete the env-specific compile-time configs.  Update your `config/config.exs` to include blocks for each config environment.  This replaces the need for the `import_config "#{config_env()}.exs"` line, which is what usually loads up a specific configuration file.

### `config/config.exs`

```elixir
# compile-time config
import Config

# Dev
if config_env() == :dev do
    config :logger, :console, 
        level: :debug,
        format: "[$level] $message\n"
end

# Test
if config_env() == :test do
    config :logger, :console, 
            level: :warning,
            format: "[$level] $message\n"
end

# Prod
if config_env() == :prod do
    config :logger, :console,
        format: "$time $metadata[$level] $message\n",
        level: :info,
        metadata: [:request_id]
end
```

Logger configuration is an interesting example -- because the `Logger` relies on macros, it is affected by compile-time considerations. Although you _can_ configure the logger level at runtime, that has a different effect than configuring it at compile-time.  If you set the logger level to `:info` at runtime, then you will only see info, warning, or error messages in the logs... but the important thing is that the calls to `Logger.debug/2` are still there in the code. Calls to those functions are still made, but the output is silenced.

By comparison, if you set the logger level to `:info` in the compile-time config, all calls to `Logger.debug/2` are _removed_ from the compiled application.  Calls are no longer made to `Logger.debug/2` because _that function no longer exists_. That distinction may not matter for small apps, but you can imagine that those milliseconds can add up for mission-critical applications where performance is paramount.

Phoenix relies on macros to generate routes, so you must configure certain things at compile time. Consider the following bits of configuration from a Phoenix application:

```elixir
# Compile-time config
config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Enable dev routes for dashboard and mailbox (compile-time config)
config :your_app, dev_routes: true
```

Those _must_ be defined at compile-time because it controls how the application gets built.  You can put these types of configuration details into the appropriate environment block in the compile-time `config.exs`.

### `config/runtime.exs`

Your `runtime.exs` can include whatever it needs to, i.e. all the application configuration that can happen at runtime and you know that the calls to `Dotenv.source/2` will be responsible for loading up the proper `.env` files for the given environment.

```elixir
import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"

source!([
  "#{env_dir_prefix}.env",
  "#{env_dir_prefix}.#{config_env()}.env",
  "#{env_dir_prefix}.#{config_env()}.overrides.env",
  System.get_env()
])


config :myapp, MyApp.Repo,
  database: env!("DATABASE", :string!),
  username: env!("USERNAME", :string),
  password: env!("PASSWORD", :string),
  hostname: env!("HOSTNAME", :string!),
  pool_size: env!("POOL_SIZE", :integer),
  adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
  pool: env!("POOL", :module?)

  # etc...
```
