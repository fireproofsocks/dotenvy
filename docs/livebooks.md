# Livebooks

When running an Elixir application from a [Livebook](https://livebook.dev/), we run into a familiar problem of resolving relative file names. The `.env` path that made sense when you started your app from your application root using `mix` will not work when starting the app from a `Livebook` server in some unknown directory.

In order to overcome this problem, it is important to resolve the relative paths to your `.env` files into absolute paths.  As demonstrated elsewhere, this can be done using `Path.expand/1`:

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"

source!([
  "#{env_dir_prefix}.env",
  "#{env_dir_prefix}.#{config_env()}.env",
  "#{env_dir_prefix}.#{config_env()}.overrides.env",
  System.get_env()
])
```

Now your Livebooks can install apps using `Dotenvy` as you would other applications:

```elixir
Mix.install(
  [
    {:app_using_dotenvy, path: "/path/to/app_using_dotenvy", env: :dev}
  ],
  config_path: :app_using_dotenvy,
  lockfile: :app_using_dotenvy
)
```
