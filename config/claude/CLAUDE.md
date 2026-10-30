# Global Development Preferences

## Python Package Management
- Use uv exclusively for all Python package management. NEVER use pip, poetry, or conda.
- Install: `uv add <package>` | Dev: `uv add --dev <package>`
- Run: `uv run python script.py` | Tests: `uv run pytest`
- Sync: `uv sync` | Lock: `uv lock`

## Python Code Quality
- Use ruff for linting AND formatting (replaces flake8, black, isort).
- Lint: `uv run ruff check .` | Format: `uv run ruff format .`
- Type hints on all function signatures. Use `from __future__ import annotations`.
- Python 3.11+ minimum.
