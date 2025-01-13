# Generators

The [Dotenvy Generators](https://hexdocs.pm/dotenvy_generators/) package includes mix tasks which are designed to spin up new Elixir applications that leverage `Dotenvy` to read environment variables. This is one of the easiest ways to see `Dotenvy` in action.

The most important tasks include:

- `dot.new`: a variant of the humble `mix new` task
- `phx.new`: an alternate of the Phoenix `mix phx.new` task, used to spin up Phoenix applications

## Installing the Dotenvy Generators

In order to install the `Dotenvy` generator scripts, you need to run two commands from your terminal: one to remove the `phx_new` generators (if present), and one to install the `dotenvy_generators`.  Run the following two commands:

    mix archive.uninstall phx_new
    mix archive.install hex dotenvy_generators

Once this has executed successfully, you should see the `dot.new` task as one of the available tasks when you run `mix help`.

We have to uninstall the `phx_new` generators because `dotenvy_generators` uses the same names for its mix tasks (this may change later... stat tuned).

See also the dedicated instructions in the [Dotenvy Generators](https://hexdocs.pm/dotenvy_generators/) package.
