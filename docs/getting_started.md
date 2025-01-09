# Getting Started

The concept of environment variables is simple and `Dotenvy` aims to make your application take advantage of them, but how can you start using them easily in your application?

The easiest way to start using `Dotenvy` for your Elixir projects is to try out one of the [Dotenvy Generators](https://hexdocs.pm/dotenvy_generators/).  These are mix tasks designed to spin up new Elixir applications that leverage `Dotenvy` to read environment variables.

## Installing the Dotenvy Generators

See also the dedicated instructions in the [Dotenvy Generators](https://hexdocs.pm/dotenvy_generators/) package.

In order to install the `Dotenvy` generator scrips, you need to run two commands from your terminal: one to remove the `phx_new` generators (if present), and one to install the `dotenvy_generators`.  Run the following two commands:

    mix archive.uninstall phx_new
    mix archive.install hex dotenvy_generators

Once this has executed successfully, you should see the `dot.new` task as one of the available tasks when you run `mix help`.

## The dot.new generator

The `dot.new` mix task is available when you have installed the `dotenvy_generators` as described above. We can use it generate a new Elixir app:

    mix dot.new example

Follow the prompts given:

    cd example
    mix deps.get

And take a moment to look around the folder structure and note the `envs/` directory. A sample environment variable is declared: `SECRET`. Your `runtime.exs` should include a line which reads

    config :example, :secret, env!("SECRET", :string!)

> #### ENV vars are not available outside the parser {: .info}
>
> By default, ENV vars from in your `.env` files are *not* exported back to
> the system; i.e. `System.put_env/2` is NOT called by default. In other words,
> declaring a variable `FOO` in one of your parsed `.env` files does not mean that
> `System.get_env/2` will return anything. This encapsulation is by design!
>
> If you really need to make these variables available to `System.get_env/2`, you
> can pass `&System.put_env/1` as the `:side_effect`. If you do this, make sure the
> last argument to `Dotenvy.source/2` is `System.get_envs()`
