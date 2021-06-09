# Strategies

Although there are other places where `Dotenvy` may prove useful, it was designed with the `config/runtime.exs` in mind: most of the following use-cases will focus on that because it offers a clean and declarative way to load up the necessary variables.

## A Note on Configuration Providers

[Configuration providers](https://hexdocs.pm/elixir/Config.Provider.html) are most often invoked in the context of releases, and although they can solve certain problems that arise in production deployments, they tend to be an awkward fit for regular day-to-day development. `Dotenvy` seeks to normalize how configuration is loaded across environments, so having different methods depending on how you run your app is antithetical. We do not want some code that runs only in certain environments and not in others: it can make for untested or untestable code.

Secondly, configuration providers sometimes shift the task of "shaping" the configuration out of Elixir and into some static representation (e.g. JSON or TOML). The allure of a straight-forward static file is deceiving because there is no easy way to delineate Elixir-specific subtleties such as distinguishing between keyword lists and maps. When configuration providers "solve" one problem, they often create another: it can require some busywork to convert values back into Elixir variable types that your application requires.

For these reasons, `Dotenvy` does not rely on [configuration providers](https://hexdocs.pm/elixir/Config.Provider.html); dotenv files are an easier "lingua franca".

## Dotenv for Dev and Prod

The distinctions between "dev" and "prod" become less clear when we focus on configuration: ideally, the app is the same in all environments, it is only the configuration _values_ themselves that can be described as "dev" or "prod" -- in this example they will live inside a `.env` file.

Let's look at the three files that will make this work:

### `config/config.exs`

    # compile-time config
    import Config

    config :myapp,
    ecto_repos: [MyApp.Repo]

    config :myapp, MyApp.Repo,
    migration_timestamps: [
        type: :utc_datetime,
        inserted_at: :created_at
    ]

### `config/runtime.exs`

    import Config
    import Dotenvy

    source(".env")

    if config_env() == "test" do
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

### `.env` (dev or prod)

    DATABASE=myapp_dev
    USERNAME=myuser
    PASSWORD=mypassword
    HOSTNAME=localhost
    POOL_SIZE=10
    POOL=

The `.env` shows some values suitable local development; if the app were deployed on a production box, it would be the same shape, but its values would point to a production database. For tests, values are hard-coded inside `runtime.exs`. This is one admittedly heavy-handed way to ensure that your test runs don't accidentally hit the wrong database, but it does mean that there is a small block of untestable code inside the if-statement.

You may notice that in this example we have done away with `config/dev.exs`, `config/test.exs`, and `config/prod.exs`. These should be used _only_ when your app has a legitimate compile-time need.  If you _can_ configure something at runtime, you _should_ configure it at runtime.  These extra config files are omitted to help demonstrate how the decisions about how the app should run can often be pushed into `runtime.exs`. This should help avoid confusion that often arises between compile-time and runtime configuration.

## Dotenvs for All Environments

It is possible to use _only_ a `config.exs` and a `runtime.exs` file to configure
many Elixir applications: let the `.env` tell the app how to run!
Consider the following setup:

### `config/config.exs`

    # compile-time config
    import Config

    config :myapp,
    ecto_repos: [MyApp.Repo]

    config :myapp, MyApp.Repo,
    migration_timestamps: [
        type: :utc_datetime,
        inserted_at: :created_at
    ]

### `config/runtime.exs`

    import Config
    import Dotenvy

    source([".env", ".env.\#{config_env()}"])

    config :myapp, MyApp.Repo,
        database: env!("DATABASE", :string!),
        username: env!("USERNAME", :string),
        password: env!("PASSWORD", :string),
        hostname: env!("HOSTNAME", :string!),
        pool_size: env!("POOL_SIZE", :integer),
        adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
        pool: env!("POOL", :module?)

### `.env` (dev or prod)

    DATABASE=myapp_dev
    USERNAME=myuser
    PASSWORD=mypassword
    HOSTNAME=localhost
    POOL_SIZE=10
    POOL=

### `.env.test`

    DATABASE=myapp_test
    USERNAME=myuser
    PASSWORD=mypassword
    HOSTNAME=localhost
    POOL_SIZE=10
    POOL=Ecto.Adapters.SQL.Sandbox

The above setup would likely commit the `.env.test` file so it was sure to override, and add `.env` to `.gitignore`, but other strategies are possible.  The above example demonstrates developer settings appropriate for local development in the sample `.env` file, but a production deployment would only differ in its _values_: the shape of the file would be the same.

The `.env.test` file is loaded when running tests, so its values override any of the
values set in the `.env`, but they would _not_ override any pre-existing system variables because the `:overwrite?` option is `false` by default.

By using `Dotenvy.env!/2`, a strong contract is created with the environment: the
system running this app _must_ have the designated environment variables set somehow,
otherwise this app will not start (and a specific error will be raised).

Using the nil-able variants of the type-casting (those ending with `?`) is an easy
way to fall back to `nil` when the variable contains an empty string: `env!("POOL", :module?)` requires that the `POOL` variable is set, but it will return a `nil` if the value is an empty string.

See `Dotenvy.Transformer` for more details.
