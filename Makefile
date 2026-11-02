.PHONY: check build
check:
	uv run ruff check .
	uv run ruff format --check .
	uv run pytest -q
build:
	uv run reservation-patterns build
