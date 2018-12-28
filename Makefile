# Hammer makefile

default: format test docs credo coveralls


format:
	mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}"


test: format
	mix test --no-start


docs: format
	mix docs


coveralls:
	mix coveralls --no-start


coveralls-travis:
	mix coveralls.travis --no-start


repl:
	iex -S mix


.PHONY: format test docs credo coveralls coveralls-travis
