ExUnit.start(exclude: [:skip])

Mox.Server.start_link([])

Mox.defmock(ParserMock, for: Dotenvy)
