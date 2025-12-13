.PHONY: ci compile check_format format credo test type_check shell release

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

release:
	@echo "Last 5 tags:"
	@git tag --sort=-version:refname | head -n 5
	@echo ""
	@read -r -p "Enter the next tag (e.g., 1.0.0): " tag && [ -n "$$tag" ] || { echo "Tag cannot be empty. Aborted."; exit 1; }; \
	read -r -p "Did you update the README install instructions? (Y/N) " a && [ "$$a" = "Y" ] || { echo "Aborted."; exit 1; }; \
	git tag "$$tag" && \
	mix compile && \
	mix hex.publish && \
	git push origin "$$tag" && \
	echo "Released and tagged as $$tag"
