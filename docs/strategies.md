# Strategies

Although there are other places where `Dotenvy` may prove useful, it was designed with the `config/runtime.exs` in mind: most of the following use-cases will focus on that because it offers a clean and declarative way to load up the necessary variables.

## Dotenv for Dev and Prod

The distinctions between "dev" and "prod" become less clear when we focus on configuration: ideally, the app is the same in all environments, it is only the configuration _values_ themselves that can be described as "dev" or "prod" -- in this example they will live inside a single `.env` file.

Let's look at the three files that will make this work:

### `config/config.exs`

```elixir
# compile-time config
import Config

config :myapp,
ecto_repos: [MyApp.Repo]

config :myapp, MyApp.Repo,
migration_timestamps: [
  type: :utc_datetime,
  inserted_at: :created_at
]
```

### `config/runtime.exs`

```elixir
import Config
import Dotenvy

source([".env", System.get_env()])

if config_env() == :test do
  config :myapp, MyApp.Repo,
    database: "myapp_test",
    username: "test-user",
    password: "test-password",
    hostname: "localhost",
    pool_size: 10,
    adapter: Ecto.Adapters.Postgres,
    pool: Ecto.Adapters.SQL.Sandbox
else
  config :myapp, MyApp.Repo,
    database: env!("DATABASE", :string!),
    username: env!("USERNAME", :string),
    password: env!("PASSWORD", :string),
    hostname: env!("HOSTNAME", :string!),
    pool_size: env!("POOL_SIZE", :integer),
    adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
    pool: env!("POOL", :module?)
end
```

### `.env` (dev or prod)

```env
DATABASE=myapp_dev
USERNAME=myuser
PASSWORD=mypassword
HOSTNAME=localhost
POOL_SIZE=10
POOL=
```

The `.env` shows some values suitable local development; if the app were deployed on a production box, it would be the same shape, but its values would point to a production database. For tests, values are hard-coded inside `runtime.exs`. This is one admittedly heavy-handed way to ensure that your test runs don't accidentally hit the wrong database, but it does mean that there is a small block of untestable code inside the if-statement.

You may notice that in this example we have done away with `config/dev.exs`, `config/test.exs`, and `config/prod.exs`. These should be used _only_ when your app has a legitimate compile-time need. If you _can_ configure something at runtime, you _should_ configure it at runtime. These extra config files are omitted to help demonstrate how the decisions about how the app should run can often be pushed into `runtime.exs`. This should help avoid confusion that often arises between compile-time and runtime configuration.

## Dotenvs for All Environments

It is possible to use _only_ a `config.exs` and a `runtime.exs` file to configure
many Elixir applications: let the `.env` tell the app how to run!
Consider the following setup:

### `config/config.exs`

```elixir
# compile-time config
import Config

config :myapp,
ecto_repos: [MyApp.Repo]

config :myapp, MyApp.Repo,
migration_timestamps: [
  type: :utc_datetime,
  inserted_at: :created_at
]
```

### `config/runtime.exs`

```elixir
import Config
import Dotenvy

source([".env", ".env.\#{config_env()}", System.get_env()])

config :myapp, MyApp.Repo,
  database: env!("DATABASE", :string!),
  username: env!("USERNAME", :string),
  password: env!("PASSWORD", :string),
  hostname: env!("HOSTNAME", :string!),
  pool_size: env!("POOL_SIZE", :integer),
  adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
  pool: env!("POOL", :module?)
```

### `.env` (dev or prod)

```env
DATABASE=myapp_dev
USERNAME=myuser
PASSWORD=mypassword
HOSTNAME=localhost
POOL_SIZE=10
POOL=
```

### `.env.test`

```env
DATABASE=myapp_test
USERNAME=myuser
PASSWORD=mypassword
HOSTNAME=localhost
POOL_SIZE=10
POOL=Ecto.Adapters.SQL.Sandbox
```

The above setup would likely commit the `.env.test` file so it was sure to override, and add `.env` to `.gitignore`, but other strategies are possible. The above example demonstrates developer settings appropriate for local development in the sample `.env` file, but a production deployment would only differ in its _values_: the shape of the file would be the same.

The `.env.test` file is loaded when running tests, so its values override any of the
values set in the `.env`.

By using `Dotenvy.env!/2`, a strong contract is created with the environment: the
system running this app _must_ have the designated environment variables set somehow,
otherwise this app will not start (and a specific error will be raised).

Using the nil-able variants of the type-casting (those ending with `?`) is an easy
way to fall back to `nil` when the variable contains an empty string: `env!("POOL", :module?)` requires that the `POOL` variable is set, but it will return a `nil` if the value is an empty string.

See `Dotenvy.Transformer` for more details.

## Releases

One of the hurdles when dealing with Elixir releases is that only certain files are packaged into them. One solution to this is to specify additional directories to include in the release via the `overlays` option in your `mix.exs`, e.g. an `envs/` directory which contains your `.env` files:

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

> ### Overlays {: .info}
>
> When you specify a folder in the `overlays` option in your `mix.exs`, then the
> _contents_ (and not the folder itself) will be copied to the root of the release.

Since these files are copied to the root of your release, the relative paths used in your `runtime.exs` will not be able to find them when your app is running in the context of a release. One solution to this is to rely on the `RELEASE_ROOT` system environment variable which is set when a release is run. If this value exists, it will represent the fully qualified path to your release; this variable will not be set when running your app locally (e.g. during development).

We can use the presence of the `RELEASE_ROOT` to determine a directory prefix for where to look for our `.env` files, e.g.:

```elixir
import Config
import Dotenvy

# For local development, read dotenv files inside the envs/ dir;
# for releases, read them at the RELEASE_ROOT
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/")

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    System.get_env()
])
```

Or more succinctly:

```elixir
config_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/") <> "/"
```

Remember that is safer to use an absolute path. This is especially important when working with umbrella apps or Livebooks.

## Umbrella Apps

Elixir [Umbrella Projects](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html) consume configuration slightly differently due to how they are organized.

In particular, you have to be very careful about relative paths when working in an umbrella project. Depending on what you're doing, the path may be _relative to a single application_ instead of relative to the root of the repository. As elsewhere, using `Path.expand/1` is a good way to anchor your `config/runtime.exs` to point to the root of the repository instead of it resolving to the root of a specific application within the umbrella. E.g.

```elixir
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs/")

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    System.get_env()
  ])
```
