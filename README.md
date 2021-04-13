# Dotenvy

[![Module Version](https://img.shields.io/hexpm/v/dotenvy.svg)](https://hex.pm/packages/dotenvy)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/dotenvy/)
[![Total Download](https://img.shields.io/hexpm/dt/dotenvy.svg)](https://hex.pm/packages/dotenvy)
[![License](https://img.shields.io/hexpm/l/dotenvy.svg)](https://hex.pm/packages/dotenvy)
[![Last Updated](https://img.shields.io/github/last-commit/fireproofsocks/dotenvy.svg)](https://github.com/fireproofsocks/dotenvy/commits/master)

`Dotenvy` is an Elixir implementation of the original [dotenv](https://github.com/bkeepers/dotenv) Reby gem, **compatible with mix and releases**. It is designed to help the development of applications following the principles of the [12-factor app](https://12factor.net/) and its recommendation to store configuration in the environment.

## Installation

Add `dotenvy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dotenvy, "~> 0.1.0"}
  ]
end
```

It has no dependencies.

## Usage

`Dotenvy` is designed to help configure your application _at runtime_, and one
of the most effective places to do that is inside `config/runtime.exs` (available
since Elixir v1.11).

The `Dotenvy.source/2` function can accept a list of paths of where to look for dotenv files -- when combined with `Config.config_env/0` it is easy to load up environment-specifc config, e.g.

```elixir
source([".env", ".env.\#{config_env()}", ".env.\#{config_env()}.local"])
```

By default, the listed files do not _need_ to exist -- if no file exists at the specified path, the next path is tried. This makes it easy to commit basic files for default values and basic funcitonality, and still leave the door open to developers so they can override them with their own configurations.

For a simple exmample, we can load a single file:

```elixir
# config/runtime.exs
import Config
import Dotenvy

source!(".env")

config :myapp, MyApp.Repo,
    database: env!("DATABASE", :string!),
    username: env!("USERNAME", :string),
    password: env!("PASSWORD", :string),
    hostname: env!("HOSTNAME", :string!),
    pool_size: env!("POOL_SIZE", :integer),
    adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
    pool: env!("POOL", :module?)
```

And then define your variables in the file(s) to be sourced. `Dotenvy` has no opinions about what you name your files; `.env` is merely a convention.

```
# .env
DATABASE=myapp_dev
USERNAME=myuser
PASSWORD=mypassword
HOSTNAME=localhost
POOL_SIZE=10
POOL=
```

When you set up your application configuration in this way, you are creating a contract
with the environment (errors will be raised if certain system variables are not set),
and this is an approach that works equally well for your day-to-day development and testing, as well as for mix releases.

Read the [configuration strategies](docs/strategies.md) for other more detailed examples of how to configure your app.

Refer to the ["dotenv" (`.env`) file format](docs/dotenv-file-format.md) for more examples and features of the supported syntax.

See the `Dotenvy` module documentation on its functions.

### Note for Mix Tasks

If you have authored your own Mix tasks, you must ensure that they load the
application configuration in a way that is compatible with the runtime config.
A good way to do this is to include `Mix.Task.run("app.config")` inside the
`run/1` implementation, e.g.

```elixir
def run(_args) do
  Mix.Task.run("app.config")
  # ...
end
```  

Image Attribution: "dot" by Stepan Voevodin from the [Noun Project](https://thenounproject.com/)