# Releases

One of the hurdles when dealing with Elixir releases is that only certain files are packaged into them.  Any new ad-hoc files like our `.env` files are not included by default.  One way to ensure that our additional files get packaged into the release is to specify the [`overlays` option](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-options) in your `mix.exs`. To do this we edit the `mix.exs` file to specify the `envs/` directory which contains your `.env` files:

```elixir
# mix.exs

def project do
  [
    app: :your_app,
    # ... 
    releases: releases()
  ]
end

defp releases do
  [
    myapp: [
        overlays: ["envs/"]
    ]
  ]
end
```

> #### Overlays {: .info}
>
> When you specify a folder in the `overlays` option in your `mix.exs`, then the
> _contents_ (and not the folder itself) will be copied to the root of the release.

During day-to-day development, your `.env` files live inside the `envs/` folder, but when a release is built, they get copied to the _root_ of the release, so we cannot rely on relative paths in `runtime.exs`!  In our examples, we rely on `Path.expand/2` and the presence of the `RELEASE_ROOT` system environment variable to resolve our relative paths into absolute paths.

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"
```

This is a simple trick to ensure that we always have a fully-qualified path to where our `.env` files live. Putting them inside a folder named `envs/` is merely a convention: you are free to store them where you wish, but keep in mind that it is easier to deal with _folders_ than it is with individual files.  See the documentation on [Overlays](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-overlays) for more information.

Our `config/runtime.exs` will look something like the following. Note that the folder referenced in the `mix.exs` overlays section (`envs/`) must correspond with the path referenced in `config/runtime.exs`.

```elixir
import Config
import Dotenvy

# For local development, read dotenv files inside the envs/ dir;
# for releases, read them at the RELEASE_ROOT
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"

source!([
  "#{env_dir_prefix}.env",
  "#{env_dir_prefix}.#{config_env()}.env",
  "#{env_dir_prefix}.#{config_env()}.local.env",
  System.get_env()
])
```

Remember that is always safer to use an absolute path. This is especially important when working with umbrella apps or Livebooks!

## Umbrella Apps

Elixir [Umbrella Projects](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html) consume configuration slightly differently due to how they are organized.

In particular, you have to be very careful about relative paths when working in an umbrella project. Depending on what you're doing, the path may be _relative to a single application_ instead of relative to the root of the repository. As elsewhere, using `Path.expand/1` is a good way to anchor your `config/runtime.exs` so it resolves to the same directory no matter if the app is running during local development or if it's running as a release. Once again, the winning pattern for your `config/runtime.exs` will look something like this:

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"

source!([
  "#{env_dir_prefix}#{config_env()}.env",
  "#{env_dir_prefix}#{config_env()}.local.env",
  System.get_env()
])
```
