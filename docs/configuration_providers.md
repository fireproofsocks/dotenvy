# Configuration Providers

[Configuration providers](https://hexdocs.pm/elixir/Config.Provider.html) are most often invoked in the context of releases. Although they can solve certain problems that arise in production deployments, they tend to be an awkward fit for regular day-to-day development. `Dotenvy` seeks to normalize how configuration is loaded across environments, so having different methods depending on how you run your app is antithetical. We do not want some code that runs only in certain environments and not in others: it can make for untested or untestable code!

Secondly, configuration providers sometimes shift the task of "shaping" the configuration out of Elixir and into some static representation (e.g. JSON or TOML). The allure of a straight-forward static file is deceiving because there is no easy way to delineate Elixir-specific subtleties such as distinguishing between keyword lists and maps. For example, how do you distinguish between a tuple and a list in TOML? How can you indicate a map with string keys or atom keys when you are representing it as a JSON object?  

When configuration providers "solve" one problem, they often create another: it can require some busywork to convert values back into Elixir variable types that your application requires and the mental friction can really accumulate.

For these reasons, `Dotenvy` does not rely on [configuration providers](https://hexdocs.pm/elixir/Config.Provider.html); `.env` files are an easier _lingua franca_.  As of `Dotenvy` version 1.0.0 and its support of shell commands, it's easier than ever to populate environment variables by using standard CLI tools to read values from password managers or other services.  See the page on [1Password](docs/1password.md) for and example.
