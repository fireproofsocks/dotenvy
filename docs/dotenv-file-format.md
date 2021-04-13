# Dotenv File Format

`.env` files (a.k.a. "dotenv") store key-value pairs in a format descended from
simple bash files that exported environment variables.

This implementation cleaves closely to format described by the original [dotenv](https://github.com/bkeepers/dotenv) package, but it is not a direct match (by design).

Typically, a dotenv (`.env`) file is formatted into simple key-value pairs:

    S3_BUCKET=YOURS3BUCKET
    SECRET_KEY=YOURSECRETKEYGOESHERE

You may add `export` in front of each line so you can `source` the file in bash (see `Dotenvy.source/2`):

    export S3_BUCKET=YOURS3BUCKET
    export SECRET_KEY=YOURSECRETKEYGOESHERE

## Variable Names

For the sake of portability (and sanity), environment variable names must consist solely of letters, digits, and the underscore ( `_` ) and must not begin with a digit. In regex-speak:

    [a-zA-Z_]+[a-zA-Z0-9_]*

### Example variable names

    DATABASE_URL  # ok  
    foobar        # ok  
    NO-WORK       # <-- invalid !!!
    ÜBER          # <-- invalid !!!
    2MUCH         # <-- invalid !!!

## Values

Values are what lie to the right of the equals sign. They may be quoted.
Using single quotes will prevent variables from being interpolated.

    SIMPLE=xyz123
    INTERPOLATED="Multiple\\nLines and variable substitution: ${SIMPLE}"
    NON_INTERPOLATED='raw text without variable interpolation'
    MULTILINE = """
    long text here,
    e.g. a private SSH key
    """

## Escape Sequences

The following character strings will be interpreted (i.e. escaped) as specific codepoints in the same way you would expect if the values were assigned inside a script. Remember: when a text file is read, it is read as a series of utf8 encoded code points.

- `\n` Linefeed (aka newline); `<<92, 110>>` -> `<<10>>`
- `\r` Carriage return; `<<92, 114>>` -> `<<13>>`
- `\t` Tab; -> `<<92, 116>>` -> `<<9>>`
- `\f` Form feed; -> `<<92, 102>>` -> `<<12>>`
- `\b` Backspace; -> `<<92, 98>>` -> `<<8>>`
- `\"` Double-quote; ->  `<<92, 34>>` -> `<<34>>`
- `\'` Single-quote; -> `<<92, 39>>` -> `<<39>>`
- `\\` Backslash; -> `<<92, 92>>` -> `<<92>>`
- `\uFFFF` Unicode escape (4 hex characters to denote the codepoint)

If a backslash precedes any other character, that character will be interpretted literally: the backslash will be ignored and removed from output.

### Interpolation (a.k.a. Variable Substitution)

Values left unquoted or wrapped in double-quotes will interpolate variables in the the `${VAR}` syntax. This can be useful for referencing existing system environment variables or to reference varaibles previously parsed.

For example:

    USER=admin
    EMAIL=${USER}@example.org
    DATABASE_URL="postgres://${USER}@localhost/my_database"
    CACHE_DIR=${PWD}/cache

Multi-line values (e.g. private keys) can use the triple-quoted heredoc syntax:

    PRIVATE_KEY="""
    -----BEGIN RSA PRIVATE KEY-----
    ...
    HkVN9...
    ...
    -----END DSA PRIVATE KEY-----
    """

### Non-Interpolated

If your values must retain `${}` in their output, wrap the value in single quotes, e.g.:

    PASSWORD='!@G0${k}k'
    MESSAGE_TEMPLATE='''
        Hello ${PERSON},

        Nice to meet you!
    '''

## Comments

The hash-tag `#` symbol denotes a comment when on its own line or when it follows a quoted value.  It is not treated as a comment when it appears within quotes.

    # This is a comment
    SECRET_KEY=YOURSECRETKEYGOESHERE # also a comment
    SECRET_HASH="something-with-a-hash-#-this-is-not-a-comment"
