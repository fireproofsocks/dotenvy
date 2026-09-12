# Reading & Casting Values

Your `runtime.exs` will look something like this:

```elixir
import Config
import Dotenvy

source!(["envs/.#{config_env()}.env", System.get_env()])
```

See the [Releases](docs/guides/releases.md) document for a thorough example of how to properly load up environment-specific files both for local development and in the context of a built & deployed release.

> ### Remember the Things {: .info}
>
> - Environment variables are always strings
> - a `?` suffix on the type arg turns an empty string into a `nil`
> - a `!` suffix on the type arg causes an empty string to raise an exception
> - no special suffix causes an empty string to be cast to a "sensible" value, e.g. `0` for integer or `false` for boolean.
> - most types offer all 3 variants, but the IP address types do not: there is no safe or sensible value to infer from an empty string
> - `env!/3` returns its third argument if the given env var is not declared

## Strings

Given the following env vars:

```env
HOST=localhost
BLANK=
```

Then:

```elixir
env!("HOST", :string)
# => "localhost"

env!("BLANK", :string)
# => ""

env!("BLANK", :string?)
# => nil

env!("BLANK", :string!)
# ** (RuntimeError) Error converting variable BLANK to string!: non-empty value required

env!("NOT_SET", :string)
# ** (RuntimeError) Environment variable NOT_SET not set

env!("NOT_SET", :string, "fallback")
# => "fallback"

# Surprise! The variable is SET, so the fallback never comes into play
env!("BLANK", :string, "fallback")
# => ""
```

`:string` is the default type, so `env!/1` and `env!(var, :string)` are the same.

## Integers

Given the following env vars:

```env
PORT=5432
TIMEOUT=12abc
RATIO=1.5
GARBAGE=abc
BLANK=
```

Then:

```elixir
env!("PORT", :integer)
# => 5432

# Surprise! Parsing stops at the first character it cannot read
env!("TIMEOUT", :integer)
# => 12

env!("RATIO", :integer)
# => 1

env!("GARBAGE", :integer)
# ** (RuntimeError) Error converting variable GARBAGE to integer: Unparsable as integer

env!("BLANK", :integer)
# => 0

env!("BLANK", :integer?)
# => nil

env!("BLANK", :integer!)
# ** (RuntimeError) Error converting variable BLANK to integer!: non-empty value required

env!("NOT_SET", :integer, 5432)
# => 5432

# Surprise! The variable is SET, so the fallback never comes into play
env!("BLANK", :integer, 5432)
# => 0
```

## Floats

Given the following env vars:

```env
RATE=1.5
WHOLE=5
MESSY=1.5abc
GARBAGE=abc
BLANK=
```

Then:

```elixir
env!("RATE", :float)
# => 1.5

# A value with no decimal point still casts to a float
env!("WHOLE", :float)
# => 5.0

# Surprise! Parsing stops at the first character it cannot read
env!("MESSY", :float)
# => 1.5

env!("GARBAGE", :float)
# ** (RuntimeError) Error converting variable GARBAGE to float: Unparsable as float

env!("BLANK", :float)
# => 0.0

env!("BLANK", :float?)
# => nil

env!("BLANK", :float!)
# ** (RuntimeError) Error converting variable BLANK to float!: non-empty value required

env!("NOT_SET", :float, 1.0)
# => 1.0
```

## Booleans

Given the following env vars:

```env
DEBUG=true
VERBOSE=FALSE
ZERO=0
NEGATIVE=no
DISABLED=off
BLANK=
```

Then:

```elixir
env!("DEBUG", :boolean)
# => true

# Case does not matter
env!("VERBOSE", :boolean)
# => false

env!("ZERO", :boolean)
# => false

# Surprise! Only "false", "0", and "" are false. Every other value is true.
env!("NEGATIVE", :boolean)
# => true

env!("DISABLED", :boolean)
# => true

env!("BLANK", :boolean)
# => false

env!("BLANK", :boolean?)
# => nil

env!("BLANK", :boolean!)
# ** (RuntimeError) Error converting variable BLANK to boolean!: non-empty value required

env!("NOT_SET", :boolean, true)
# => true
```

## Atoms

Given the following env vars:

```env
LOG_LEVEL=debug
PREFIXED=:debug
BLANK=
```

Then:

```elixir
env!("LOG_LEVEL", :atom)
# => :debug

# A leading colon is optional and gets stripped
env!("PREFIXED", :atom)
# => :debug

# Surprise! An empty string becomes the atom :""
env!("BLANK", :atom)
# => :""

env!("BLANK", :atom?)
# => nil

env!("BLANK", :atom!)
# ** (RuntimeError) Error converting variable BLANK to atom!: non-empty value required

env!("NOT_SET", :atom, :info)
# => :info
```

Because bare `:atom` casts an empty string to `:""`, prefer `:atom?` or `:atom!`.

Elixir best practices warn against declaring atoms at runtime because the BEAM does not garbage-collect them. However, reading config is executed when the application _starts_, which for many setups is when the BEAM is starting, so creating atoms may be forgivable. But if in doubt, consider `:existing_atom` instead.

## Existing Atoms

Given the following env vars:

```env
LOG_LEVEL=debug
MYSTERY=nope_xyz
BLANK=
```

Then:

```elixir
env!("LOG_LEVEL", :existing_atom)
# => :debug

env!("MYSTERY", :existing_atom)
# ** (RuntimeError) Error converting variable MYSTERY to existing_atom: "nope_xyz": not an existing atom

# Surprise! :"" is already an existing atom, so this does not raise
env!("BLANK", :existing_atom)
# => :""

env!("BLANK", :existing_atom?)
# => nil

env!("BLANK", :existing_atom!)
# ** (RuntimeError) Error converting variable BLANK to existing_atom!: non-empty value required
```

Same as `:atom`, except the atom must already exist. Use this to avoid growing
the atom table from untrusted input.

## Modules

Given the following env vars:

```env
ADAPTER=DateTime
FULL=Elixir.DateTime
BLANK=
```

Then:

```elixir
env!("ADAPTER", :module)
# => DateTime

# Surprise! The "Elixir." prefix is added for you, so leave it off
env!("FULL", :module)
# ** (ArgumentError) 1st argument: not an already existing atom

env!("BLANK", :module)
# ** (ArgumentError) 1st argument: not an already existing atom

env!("BLANK", :module?)
# => nil

env!("BLANK", :module!)
# ** (RuntimeError) Error converting variable BLANK to module!: non-empty value required
```

> ### The Module Name Must Already Exist {: .warning}
>
> One gotcha here is that **the module name must already exist as an atom**. Errors can pop up in test runs
> because mock modules are defined at runtime, so their names never appear in compiled code. The fix is to
> reference those modules in the compiled config, e.g. in `config/test.exs`.
> So if your `.test.env` has something like `HTTP_CLIENT=HttpMock` then your `config/test.exs` would need to
> add a line at the end declaring `HttpMock`:
>
> ```elixir
> import Config
> # ...
> HttpMock
> ```

## Charlists

Given the following env vars:

```env
HOST=localhost
BLANK=
```

Then:

```elixir
env!("HOST", :charlist)
# => ~c"localhost"

env!("BLANK", :charlist)
# => []

env!("BLANK", :charlist?)
# => nil

env!("BLANK", :charlist!)
# ** (RuntimeError) Error converting variable BLANK to charlist!: non-empty value required
```

## IP Addresses

Given the following env vars:

```env
HTTP_INTERFACE=0.0.0.0
DNS_SERVER=2001:db8::1
LOOPBACK=::1
SHORTHAND=127.1
BLANK=
```

Then:

```elixir
env!("HTTP_INTERFACE", :ipv4!)
# => {0, 0, 0, 0}

env!("DNS_SERVER", :ipv6!)
# => {8193, 3512, 0, 0, 0, 0, 0, 1}

# :ip! and :ip? accept either family
env!("LOOPBACK", :ip!)
# => {0, 0, 0, 0, 0, 0, 0, 1}

env!("HTTP_INTERFACE", :ip?)
# => {0, 0, 0, 0}

# The family-specific types reject the other family
env!("DNS_SERVER", :ipv4!)
# ** (RuntimeError) Error converting variable DNS_SERVER to ipv4!: Unparsable as IPv4 address

# Surprise! Abbreviated IPv4 forms are rejected. Write all four octets.
env!("SHORTHAND", :ipv4!)
# ** (RuntimeError) Error converting variable SHORTHAND to ipv4!: Unparsable as IPv4 address

env!("BLANK", :ip?)
# => nil

env!("BLANK", :ip!)
# ** (RuntimeError) Error converting variable BLANK to ip!: non-empty value required

env!("NOT_SET", :ip?, {127, 0, 0, 1})
# => {127, 0, 0, 1}

# Surprise! There is no suffix-less variant
env!("HTTP_INTERFACE", :ipv4)
# ** (RuntimeError) Error converting variable HTTP_INTERFACE to ipv4: Unknown type :ipv4
```

IPv6 accepts both the long form and the compressed form, and the two produce the
same tuple: `2001:0db8:0000:0000:0000:0000:0000:0001` and `2001:db8::1` both cast
to `{8193, 3512, 0, 0, 0, 0, 0, 1}`.

> ## No plain variant {: .info}
>
> Unlike other type-casts, there is no plain variant like `:ipv4` or `:ipv6`: you must supply a suffix
> like `:ipv4?` or `:ipv6!`. This is because it's difficult to conjure up a believable value out of an
> empty string AND it could be dangerous, e.g. to listening to every interface.

## Custom Functions

Pass an arity 1 function in place of a type atom. Given the following env vars:

```env
HOST=localhost
PORT=5432
```

Then:

```elixir
env!("HOST", &String.upcase/1)
# => "LOCALHOST"

env!("PORT", fn v -> String.to_integer(v) * 2 end)
# => 10864

# Raising `Dotenvy.Error` helps provide a useful error message by
# wrapping the message with the variable name
env!("HOST", fn _ -> raise Dotenvy.Error, message: "must be an IP" end)
# ** (RuntimeError) Error converting variable HOST using custom function: must be an IP

# Any other exception passes through untouched
env!("HOST", fn _ -> raise ArgumentError, "boom" end)
# ** (ArgumentError) boom
```
