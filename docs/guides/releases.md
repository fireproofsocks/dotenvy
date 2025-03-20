# Releases

One of the hurdles when dealing with Elixir releases is that only certain files are packaged into them.  Any new ad-hoc files like our `.env` files are not included by default.  One way to ensure that our additional files get packaged into the release is to specify the [`:overlays` option](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-options) in your `mix.exs`. To do this we edit the `mix.exs` file to specify the `envs/` directory which contains your `.env` files:

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
    your_app: [
        overlays: ["envs/"]
    ]
  ]
end
```

> ## Core Concept: Overlays {: .info}
>
> When you specify a folder in the `overlays` option in your `mix.exs`, then the
> _contents_ (and not the folder itself) will be copied to the root of the release.

During day-to-day development, your `.env` files live inside the `envs/` folder, but when a release is built, they get copied to the _root_ of the release, so we cannot rely on relative paths in `runtime.exs`!  In our examples, we rely on `Path.expand/2`, `Path.absname/2`, and the presence of the `RELEASE_ROOT` system environment variable to resolve our relative paths into absolute paths.

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")
```

This is a simple trick to ensure that we always have a fully-qualified path to where our `.env` files live. This pattern is repeated throughout the documentation because it is so important!

Putting your `.env` files inside a folder named `envs/` is merely a convention: you are free to store them where you wish, but keep in mind that it is easier to deal with _folders_ than it is with individual files.  See the documentation on [Mix Release Overlays](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-overlays) for more information.

Our `config/runtime.exs` will look something like the following. Note that the folder referenced in the `mix.exs` overlays section (`envs/`) must correspond with the path referenced in `config/runtime.exs`.

```elixir
import Config
import Dotenvy

# For local development, read dotenv files inside the envs/ dir;
# for releases, read them at the RELEASE_ROOT
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    System.get_env()
  ])
```

Remember that is always safer to use an absolute path. This is especially important when working with umbrella apps or [Livebooks](guides/livebooks.md)!

## Umbrella Apps

Elixir [Umbrella Projects](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html) consume configuration slightly differently due to how they are organized.

In particular, you have to be very careful about relative paths when working in an umbrella project. Depending on what you're doing, the path may be _relative to a single application_ instead of relative to the root of the repository. As elsewhere, using `Path.expand/1` and `Path.absname/2` is a good way to anchor your `config/runtime.exs` so it resolves to the same directory no matter if the app is running locally or as a release.

Once again, the winning pattern for your `config/runtime.exs` will look something like this:

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    System.get_env()
  ])
```

## Changing the envs/ folder

What if you wish to keep your `.env` files in some other folder?  No problem. You just need to update your `runtime.exs` and your `mix.exs` so the `:overlays` option corresponds to the folder name.

For example, here's what you would do if wanted to keep your `.env` files inside a directory named `xyz`:

```elixir
# config/runtime.exs
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./xyz")
# ... etc...
```

```elixir
# mix.exs
  defp releases do
    [
      my_app: [
        overlays: ["xyz/"]
      ]
    ]
  end
```

Some languages/frameworks store `.env` files at the root of the application, but this isn't easily compatible with Elixir releases.  Rather than trying to push the river, we recommend choosing a sub-folder and leveraging the `:overlays` option.
