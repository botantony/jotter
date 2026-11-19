.PHONY: install check test fmt lint ci release record bench docs-dev docs-build

# scenes to record (default: all), e.g. make record SCENES="hero plots"
SCENES ?=
# scenes recorded at once (default: a sixth of the CPU cores)
JOBS ?=
# version to release, e.g. make release VERSION=0.7.0 (default: asks)
VERSION ?=
CLIFF ?= $(shell command -v git-cliff || echo 'nix run nixpkgs\#git-cliff --')

install:
	cargo install --force --path . --locked

check:
	cargo check --all-targets

test:
	cargo test

# format with every option in rustfmt.toml (some need a nightly rustfmt)
fmt:
	nix develop .#fmt -c cargo fmt

lint:
	nix develop .#fmt -c cargo fmt --check
	cargo clippy --all-targets -- -D warnings

# what CI runs
ci: lint test

# version bump, changelog, release commit and tag, all local: nothing is
# pushed. Pushing the tag is what publishes (.github/workflows/release.yml).
release:
	@set -e; v="$(VERSION)"; \
	[ -n "$$v" ] || { printf 'version to release (now %s): ' "$$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml)"; read v; }; \
	v=$${v#v}; \
	echo "$$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "not a version: '$$v' (want X.Y.Z)"; exit 1; }; \
	[ "$$(git branch --show-current)" = main ] || { echo "not on main"; exit 1; }; \
	[ -z "$$(git status --porcelain)" ] || { echo "working tree is not clean"; exit 1; }; \
	! git rev-parse -q --verify "refs/tags/v$$v" >/dev/null || { echo "tag v$$v exists"; exit 1; }; \
	sed -i "s/^version = \".*\"/version = \"$$v\"/" Cargo.toml; \
	cargo test || { echo "tests fail: undo the bump with 'git restore Cargo.toml Cargo.lock'"; exit 1; }; \
	$(CLIFF) --tag "v$$v" -o CHANGELOG.md; \
	git commit -qam "chore: release v$$v"; \
	git tag "v$$v"; \
	echo "v$$v is committed and tagged locally. Publish with: git push origin main v$$v"

# docs clips and stills into docs/public/media
record:
	nix develop .#docs -c nu docs/media/record.nu $(if $(JOBS),-j $(JOBS)) $(SCENES)

# speed comparison with euporie (docs/media/scenes/bench-editors.nu); run it
# on an idle machine, BENCH_RUNS=n for more repetitions
bench:
	nix develop .#docs -c nu docs/media/record.nu -j 1 bench-editors

docs-dev:
	cd docs && nix develop ..#docs -c sh -c '[ -d node_modules ] || npm ci; npm run dev'

docs-build:
	cd docs && nix develop ..#docs -c sh -c '[ -d node_modules ] || npm ci; npm run build'
