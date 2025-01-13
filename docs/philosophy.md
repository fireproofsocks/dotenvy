# Philosophy

`Dotenvy` was born out of frustration with the confusing way that Elixir applications are configured when compared to many other languages and frameworks. They often contain a mishmash of compile-time and runtime configuration, and often the choice of where to configure a particular thing is more the product of _convenience_ rather than the result of thoughtful deliberation.

> ### ENV vars are not available outside the parser {: .info}
>
> If something _can_ be configured at runtime, then it _should_ be configured at runtime.

It is designed to help applications follow the principles of
  the [12-factor app](https://12factor.net/) and its recommendation to store
  configuration in the environment.

- Use declarative formats for setup automation, to minimize time and cost for new developers joining the project;
- Have a clean contract with the underlying operating system, offering maximum portability between execution environments;
- Are suitable for deployment on modern cloud platforms, obviating the need for servers and systems administration;
- Minimize divergence between development and production, enabling continuous deployment for maximum agility;
- And can scale up without significant changes to tooling, architecture, or development practices.

<https://fireproofsocks.medium.com/configuration-in-elixir-with-dotenvy-8b20f227fc0e>
