# Dotenv File Format

This implementation cleaves closely to the original [dotenv](https://github.com/bkeepers/dotenv) package, but it is not a direct match (by design).

Typically, a dotenv (`.env`) file is formatted into simple key-value pairs:

    S3_BUCKET=YOURS3BUCKET
    SECRET_KEY=YOURSECRETKEYGOESHERE

You may add `export` in front of each line so you can `source` the file in bash (see `Dotenvy.source/2`):

    export S3_BUCKET=YOURS3BUCKET
    export SECRET_KEY=YOURSECRETKEYGOESHERE

## Variable Names

For the sake of portability (and sanity), environment variable names must
consist solely of letters, digits, and the &gt;underscore&lt; ( `_` ) and
must not begin with a digit. In regex-speak:

    [a-zA-Z_]+[a-zA-Z0-9_]*

### Example variable names

    DATABASE_URL
    foobar
    NO-WORK       # <-- invalid !!!
    ÜBER          # <-- invalid !!!
    2MUCH         # <-- invalid !!!

## Values

Values are what's to the right of the equals sign. They may be quoted.
Using single quotes will prevent variables from being interpolated.

    SIMPLE=xyz123
    INTERPOLATED="Multiple\\nLines and variable substitution: ${SIMPLE}"
    NON_INTERPOLATED='raw text without variable interpolation'
    MULTILINE = \"\"\"
    long text here,
    e.g. a private SSH key
    \"\"\"

### Escape Sequences

When wrapped in quotes, the following character strings will be interpreted
(i.e. escaped) as specific codepoints in the same way you would expect if the
values were assigned inside a script.

- `\\n` Linefeed (aka newline); -> codepoint `10`
- `\\r` Carriage return; -> codepoint `13`
- `\\t` Tab; -> codepoint `9`
- `\\f` Form feed; -> codepoint `12`
- `\\b` Backspace; -> codepoint `92`
- `\\"` Double-quote; -> codepoint `34`
- `\\'` Single-quote; -> codepoint `39`
- `\\\\` Backslash; -> codepoint `92`
- `\\uFFFF` Unicode escape (4 hex characters to denote the codepoint)

If a backslash precedes any other character, that character will be interpretted
literally: the backslash will essentially be ignored and removed from output.

### Interpolation (a.k.a. Variable Substitution)

Values left unquoted or wrapped in double-quotes will interpolate variables
that are in the the `${VAR}` syntax. This can be useful to reference existing
system ENV values or to reference values previously set in a parsed file.

For example:

    USER=admin
    EMAIL=${USER}@example.org
    DATABASE_URL="postgres://${USER}@localhost/my_database"
    CACHE_DIR=${PWD}/cache

If a value must retain `${}` in its output and should not be substituted with
a value, wrap it in *single quotes* (see below).

Multi-line values (e.g. private keys) can use triple-quotes:

    PRIVATE_KEY=\"\"\"
    -----BEGIN RSA PRIVATE KEY-----
    ...
    HkVN9...
    ...
    -----END DSA PRIVATE KEY-----
    \"\"\"

### Non-Interpolated

If your values must retain `${}` in their output, wrap the value in single quotes, e.g.:

    PASSWORD='!@\\nG0${k}k'
    MESSAGE_TEMPLATE='''
        Hello ${PERSON},

        Nice to meet you!
    '''

## Comments

The hash-tag `#` symbol denotes comments, either on their own line or at the end
of a line, but not inside quotes.

    # This is a comment
    SECRET_KEY=YOURSECRETKEYGOESHERE # also a comment
    SECRET_HASH="something-with-a-hash-#-this-is-not-a-comment"
