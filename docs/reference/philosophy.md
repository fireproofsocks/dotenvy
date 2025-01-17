# Philosophy

`Dotenvy` was born out of a desire to make Elixir's configuration more explicit and cleave more closely to how many other languages and frameworks are configured. Many Elixir apps contain a mishmash of compile-time and runtime configuration that can be confusing or unpredictable. Sometimes the choice of where to configure a particular thing is more the product of _convenience_ rather than the result of thoughtful deliberation. `Dotenvy` attempts to take the guesswork out of the configuration by encouraging us to be intentional and explicit with our app and the configuration values it needs.

Taking its cue from the [12-factor app](https://12factor.net/), `Dotenvy`'s modus operandi is as follows:

1. If something _can_ be configured at runtime, then it _should_ be configured at runtime. Keep the compile-time configuration for things that must be configured at compile-time.

2. [Store configuration in the environment](https://12factor.net/config). Elixir apps configured with `Dotenvy` tend to be smaller and lighter because they are not as burdened with conditionals. Let the app be the app and let the environment provide the configuration it needs.

3. Have a clean contract with the underlying operating system: the `config/runtime.exs` can leverage `Dotenvy.env!/2` to specify exactly the values it needs in a simple declarative way.

4. Be suitable for deployment on modern cloud platforms: any system/software that can provide environment variables will work with `Dotenvy`.

5. Minimize divergence between development and production: you can end up with a version of the app that is identical across all environments.
