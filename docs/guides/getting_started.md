# Getting Started

The concept of environment variables is simple and `Dotenvy` aims to make your application take advantage of them, but how can you start using them easily in your application?  This page will walk you through kicking the tires of a simple application so you can learn how `Dotenvy` works.

> ## Prerequisite {: .info}
>
> If you haven't already, [install the `dotenvy_generators`](docs/reference/generators.md).
>
> When you run `mix help`, you should see `dot.new` as one of the available tasks. Make sure that's available before continuing.

## Generating an app

The `dot.new` mix task is available when you have installed the [`dotenvy_generators`](docs/reference/generators.md). We can use it generate a new Elixir app:

    mix dot.new example

Follow the prompts given:

    cd example
    mix deps.get

The structure should look familiar to you -- the only thing you might notice is the presence of the `envs/` directory.

## Environment-specific env files

Take a look at the `config/runtime.exs`. It includes a line like the following which reads from an environment variable named `SECRET`:

    config :example, :secret, env!("SECRET", :string!)

If you start your app using `iex -S mix` and enter into the `iex` shell:

    iex> Application.get_env(:example, :secret)
    "my-secret-dev"

This value came from the `envs/.dev.env` file, which declares the following:

    SECRET=my-secret-dev

Next, let's try running a test. Open up the `test/example_test.exs` file and edit it so we have single test like the following:

    test "reads variables specific to an env" do
        assert "my-secret-dev" == Application.get_env(:example, :secret)
    end

Then run `mix test`.  

Uh oh! The test fails because `Application.get_env(:example, :secret)` returned `"my-secret-test"` and not `"my-secret-dev"`.

Take a look at the `envs/.test.env` file and see how the variable is declared there. We can now adjust our test so the assertion matches the value we declared in our `.test.env`:

    test "reads variables specific to an env" do
        assert "my-secret-test" == Application.get_env(:example, :secret)
    end

Running `mix test` now passes!

> ### Core Concept: variables are read from an environment-specific file {: .info}
>
> Just like with Elixir's regular config files, `Dotenvy` loads the appropriate
> env file depending on your environment. Look at how the `config_env()` function
> is used in `runtime.exs` to determine the file name; different values are
> declared in the `.test.env` and `.dev.env`.

## Environment Variables

Next, let's try to access the environment variable directly:

    iex> System.get_env("SECRET")
    nil

What happened? `Application.get_env(:example, :secret)` worked, so why doesn't `System.get_env("SECRET")` see the variable?

The answer to this riddle is that `Dotenvy` is read-only: `Dotenvy` does not _set_ environment variables. This helps keep things locked down. It may be counter-intuitive, but `Dotenvy` doesn't even necessarily read environment variables!  _`Dotenvy` only reads the inputs you give it_. `Dotenvy` only reads environment variables if you pass it the output from `System.get_env()`.

> ### Core Concept: `Dotenvy` does not **set** ENV vars {: .info}
>
> Any variables you declare in your from in your `env` files are _not_ exported
> back to the system; i.e. `System.put_env/2` is NOT called. In other words,
> declaring a variable `FOO` in one of your parsed `.env` files does not mean
> `System.get_env/2` can be used to retrieve it later. This encapsulation is by design!
> If you want to set environment variables, you must do it explicitly.

## Establishing a contract

One of the tenets of the [12-factor App](https://12factor.net/) is to have a _clean contract_ with the underlying operating system, offering maximum portability between execution environments. Our `runtime.exs` is largely responsible for this: it dictates exactly which variables it needs.

To see this in action, let's add another configuration setting to our app by adding the following line to our example `runtime.exs`:

    config :example, :password, env!("PASSWORD", :string!)

Then stop and restart your app by pressing ctrl-C and running `iex -S mix` once more.  You will see an error:

    ** (RuntimeError) Environment variable PASSWORD not set

The application is declaring its contract by specifying that certain environment variables _must_ be present. Because the `PASSWORD` variable is not set, the application will not start because the contract has not been met.

We can provide the variable on the command line:

        PASSWORD=xxxx iex -S mix

And the app will start normally.

Alternatively, you can provide this value in your env files. Add the following to your `envs/.dev.exs` file:

        PASSWORD=xxxx

Your application will now start in the dev environment. However if you try to run tests, you will once again see the `RuntimeError`. You can rectify this by supplying a value in the `envs/.test.dev` file.

A good convention here is to have a default `.env` file loaded first which lists _all_ the variables that your app needs. That's a great place to put some documentation too!

> ### Core Concept: your app should dictate which variables it needs {: .info}
>
> if your application _needs_ certain configuration values to run, then it should
> _demand_ that those values are set.  The implication is that if those values aren't
> there, there's no point in starting the app because it can't do what it needs to do.
> This is the _contract with the environment_.

## Type-casting

All environment variables store string values. `Dotenvy.env!/2` and `Dotenvy.env!/3` have as their second argument an atom which determines how to convert the string value. For example, you may need to convert a `PORT` variable into an integer, other values may need to be booleans, and others may need to be atoms or modules.

There is some subtlety involved here when it comes to how empty values should be handled.

Let's revisit our `PASSWORD` variable from the previous section. Let's try setting the environment variable to an empty value before we start our app:

    $ PASSWORD= iex -S mix
    ** (RuntimeError) Error converting variable PASSWORD to string!: non-empty value required

Uh-oh! This causes another error, this time not because the variable wasn't set (it was), but because its value was _empty_.

Let's modify the line in our `runtime.exs` and replace `:string!` with `:string` (i.e. remove the exclamation point):

    config :example, :password, env!("PASSWORD", :string)

Now the application starts fine, even if the `PASSWORD` value is empty. Probably a password needs to have a value, so using `:string!` for the second argument is probably more appropriate, but you can decide this on a case-by-case basis.

Understanding type-casting is another core concept in helping to leverage `Dotenvy` so  your app get what it needs to run.

> ### Core Concept: type-casting {: .info}
>
> For each variable you read via `Dotenvy.env!/2` in `config/runtime.exs`, you
> should consider what the resulting Elixir value needs to be. Can the value be empty? Are
> `nil` values allowed? Choose the [conversion type](`t:Dotenvy.Transformer.conversion_type/0`)
> that best supplies your app with the value it needs.

See the section on [releases](docs/guides/releases.md) for further information on how `Dotenvy` works in the context of a Mix release.
