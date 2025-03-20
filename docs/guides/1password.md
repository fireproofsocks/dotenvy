# 1Password

[1Password](https://1password.com/) is a popular password manager. The [1Password CLI](https://developer.1password.com/docs/cli/get-started/) utility is a convenient way to read sensitive data out of a password vault.  The approach taken here is similar to what other password tools may require.

The syntax for accessing values out of a 1Password item is this:

```sh
op://<vault-name>/<item-name>/[section-name/]<field-name>
```

Assuming you have the `op` command installed, you can execute it and other system commands in your `.env` files by using the `$()` syntax (available since version 1.0.0 of `Dotenvy`).  For example:

```sh
DB_PASSWORD=$(op read op://MyVault/FooDatabase/password);
API_KEY=$(op read op://MyVault/ImportantAPI/key);
```

See `Dotenvy.Parser.parse/3` for examples on how to customize or restrict the functionality available inside the `$()` blocks.

## Executing Shell commands prior to version 1.0.0

If you need your variables to be populated with the output of shell commands in versions of `Dotenvy` prior to version 1.0.0, you must do a bit more footwork and rely on `System.shell/2`.  Use this with caution!

If you're unable to upgrade to version 1.0.0 or the shell commands you are attempting to run are somehow not supported by the `Dotenvy.Parser`, please file a bug! And then try the following.

Create a shell script that exports the necessary ENV vars, e.g. `secrets.sh`:

```sh
#!/bin/bash
export DB_PASSWORD=$(op read op://MyVault/FooDatabase/password);
export API_KEY=$(op read op://MyVault/ImportantAPI/key);
```

Next, we need to execute this file AND return all the values!  We do this by using `&&` in our shell command, e.g.

```elixir
System.shell(~s'bash -c "source secrets.sh && env"')
```

When it's all put together in your `config/runtime.exs` it should look something like this:

```elixir
# config/runtime.exs
import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

{raw_envs, _} = System.shell(~s'bash -c "source #{Path.absname("secrets.sh", env_dir_prefix)} && env"')
{:ok, system_env_vars} = Dotenvy.Parser.parse(raw_envs)

source!([
    Path.absname(".env", env_dir_prefix),
    Path.absname(".#{config_env()}.env", env_dir_prefix),
    Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
    system_env_vars
  ])
```

## See Also

You may need to make some adjustments to your security settings your your command line utility doesn't prompt you for authorization each time you run it:

<https://apple.stackexchange.com/questions/442220/how-to-stop-iterm2-requiring-being-granted-access-every-time>
