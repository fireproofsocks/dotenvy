# Minimal Setup

Here is another demonstration of how you can configure your app for maximum simplicity: less is more.  Per the [12-Factor App](https://12factor.net/), this strategy helps "Minimize divergence between development and production". In some cases, the `dev`, `prod`, and `test` versions of the app can be _identical_ (even down the the md5 hash) because the only differences are the configuration values supplied at runtime.

To see this strategy in action, we will abolish the `dev.ex`, `prod.exs`, and `test.exs` _entirely_ and leave _only_ the compile-time config (`config/config.exs`) and the runtime configuration (`config/runtime.exs`).

To try this out:

1. Use the `dot.new` generator to generate a new application, e.g. `mix dot.new sparse`
2. Delete the env-specific compile-time configs: `config/dev.exs`, `config/prod.exs`, and `config/test.exs`.
3. Remove the line at the end of `config/config.exs` that uses `import_config` to load these other files.  
4. If environment-specific compile-time configurations are needed, update your`config/config.exs` to include blocks for each config environment.

Here is an example of the stripped down `config/config.exs` file:

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

> ### Runtime vs. Compile-time Considerations {: .info}
>
> Logger configuration is an interesting example -- because the `Logger` relies on
> macros, it is affected by compile-time considerations. Although you _can_ configure
> the logger level at runtime, that has a different effect than configuring it at
> compile-time.  If you set the logger level to `:info` at runtime, then you will only
> see info, warning, or error messages in the logs... but the important thing is that
> _the calls to `Logger.debug/2` are still there in the code_. Calls to those functions
> are still made; only the output is silenced.
>
> By comparison, if you set the logger level to `:info` in the compile-time config, all
> calls to `Logger.debug/2` are _removed_ from the compiled application.  Calls are no
> longer made to `Logger.debug/2` because _that function no longer exists_. That
> distinction may not matter for small apps, but you can imagine that those
> milliseconds can add up for mission-critical applications where performance is
> paramount.
>
> TL;DR: Sometimes it is better to have the flexibility to change the logging level at
> runtime (e.g. to help debug some tricky problem) and sometimes it's better to control
> this at compile-time. You decide.

Phoenix relies on macros to generate routes, so you must configure certain things at compile time: its routes are compiled into existence. Consider the following bits of configuration from a Phoenix application:

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

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/")

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
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

## Optimizing Compilation Time

By default, your Elixir application compiles differently between environments, so you end up with multiple compiled artifacts in your `_build` directory.  All this extra time spent compiling and re-compiling can really add up, so it's worth asking whether or not it's necessary.

If you have an app that can be _fully_ configured at runtime and there are no differences between the compiled versions, then you can set the `:build_per_environment` option in your`mix.exs` so that all environments use the same compiled code and you no longer need to re-compile your app between environments.

```elixir
  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      build_per_environment: false
    ]
  end
```

In some cases, you may be able to leverage this even if there _are_ differences between `dev` and `prod`, but you'll have to explore the subtleties with your particular app. For example, if `dev` and `test` can share the same compiled artifacts, that may never conflict with the `prod` artifacts which may only need to be compiled on a build machine as part of your deployment pipeline. YMMV.

See [Mix Project configuration](https://hexdocs.pm/mix/Mix.Project.html#module-configuration) for the official docs.

## See Also

See the [article](https://fireproofsocks.medium.com/configuration-in-elixir-with-dotenvy-8b20f227fc0e) about using `Dotenvy` in your application for more discussion on this and other approaches.
