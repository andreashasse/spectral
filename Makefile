.PHONY: ci compile check_format format credo test type_check shell

ci: compile test credo type_check check_format

compile:
	mix compile --force --warnings-as-errors

check_format:
	mix format --check-formatted

format:
	mix format

credo:
	mix credo --strict

type_check:
	mix dialyzer

test:
	mix test

shell:
	iex -S mix
