# Fly.io

`Dotenvy` can be used when deploying an app to [Fly.io](https://fly.io/). Mostly following the instructions on the [Phoenix](docs/phoenix.md) page, but you also need to modify the `Dockerfile` so it copies over your `envs/` directory so your `.env` files are available to the `release` command.

## Dockerfile

A `Dockerfile` gets generated when you setup your app (it is ultimately generated from `mix phx.gen.release --docker`). The `Dockerfile` is ultimately what is responsible for running `mix release`, so you need to ensure that all of your files and folders are copied into the container so this command can run.

For example, if you have added a folder named `envs/` to house your `.env` files, then you need to ensure that it gets copied into the Docker container.  You will need to add a line `COPY envs envs` _before_ the `Run mix release` command.

```docker
# ... existing Docker stuf...

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel

# <---- make the directory of envs available to the release!!!
COPY envs envs

RUN mix release

# ... existing Docker stuff cont'd...
```

Once that line is there, then running `fly deploy` and other `flyctl` commands should be able to build the release and include the `.env` files as expected.

## Environment Variables

Fly.io sets a handful of environment variables when it deploys an app (which you can inspect by running `System.get_env()` from an `iex` shell).  The following are the most significant:

- `RELEASE_ROOT`
- `DATABASE_URL`
- `PHX_HOST`
- `PORT`
- `PHX_SERVER`
- `DNS_CLUSTER_QUERY`
- `SECRET_KEY_BASE`

See the [Phoenix](docs/phoenix.md) page for getting a Phoenix app to run using `Dotenvy`.
