set dotenv-load := false
container := "workspace"
workdir := "/workspace"

# Show this help
help:
  @just --list --unsorted

init:
  pre-commit install
  docker -v
  docker-compose -v

# Build/rebuild templates and docker image
build:
  just _gomplate "-f .meta/tmpl/.env.tmpl -o .env"
  just _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build
  touch .meta/var/.bash_history

validate:
  just _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"
  cat .meta/var/Dockerfile | docker-compose run --rm {{ container }} hadolint -
  docker-compose run --rm {{ container }} pre-commit run

# Run bash terminal inside container
sh:
  docker-compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm {{ container }} bash

# Switch to AWS profile using aws-vault
profile profile="":
  cd {{ invocation_directory() }} \
    && aws-vault exec --duration=8h \
    {{ if profile != "" { profile } else { `just _gomplate "-i '{{ .config.awsVaultProfile }}' --exec-pipe -- tr -d '\r'"` } }}

_gomplate args:
  @docker run --rm -v "{{ justfile_directory() }}:/src" -w /src -u $(id -u) hairyhenderson/gomplate:stable-alpine \
    -d global=config.yaml \
    $(test -e config.local.yaml && echo "-d local=config.local.yaml") \
    $(test -e config.local.yaml || echo "-d local=config.yaml") \
    -c "config=merge:local|global" \
    {{ args }}

# Install workspace to the project
install:
  @[ ! -L "{{ justfile_directory() }}/.meta" ] || (echo "Should be ran in the template itself" && false)
  ln -fs {{ file_name(justfile_directory()) }}/.meta ../.meta
  -rm {{ justfile_directory() }}/.meta/.meta
  ln -fs {{ file_name(justfile_directory()) }}/config.yaml ../config.yaml
  ln -fs {{ file_name(justfile_directory()) }}/docker-compose.yml ../docker-compose.yml
  ln -fs {{ file_name(justfile_directory()) }}/.gitleaks.toml ../.gitleaks.toml
  ln -fs {{ file_name(justfile_directory()) }}/Justfile ../Justfile
  cd .. && git config core.excludesFile {{ file_name(justfile_directory()) }}/project.gitignore
