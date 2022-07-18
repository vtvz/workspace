set dotenv-load := false

container := "workspace"
workdir := "/workspace"
just := quote(just_executable())
this := just + " -f " + quote(justfile())

# Show this help
help:
  @{{ this }} --list --unsorted

init:
  -pre-commit install --allow-missing-config
  docker -v
  docker-compose -v

# Removes branches without remote
git-cleanup:
  git fetch -p && git branch --format='%(refname:short)%09%(upstream:track)' | grep -e '\[gone\]$' | awk '{print $1}' | xargs git branch -D

# Build/rebuild templates and docker image
build prebuild='false':
  {{ this }} build-dotenv
  {{ this }} _build-dockerfile
  {{ if prebuild == 'false' { 'true' } else { 'false' } }} || cat .meta/var/Dockerfile \
    | grep -P "FROM .* as .*" \
    | sed 's/FROM .* as //' \
    | DOCKER_BUILDKIT=1 xargs -n1 -I {} docker build -t ws -f .meta/var/Dockerfile --target {} .
  {{ this }} compose build
  touch .meta/var/.bash_history

@_build-dockerfile:
  {{ this }} _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"

build-dotenv:
  {{ this }} _gomplate "-f .meta/tmpl/.env.tmpl -o .env"

@compose *args:
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose -f .ws.docker-compose.yml {{ args }}

validate:
  {{ this }} _build-dockerfile
  cat .meta/var/Dockerfile | {{ this }} compose run --rm -T {{ container }} hadolint -
  {{ this }} compose run --rm {{ container }} pre-commit run

ks:
  {{ this }} _gomplate "-f .meta/tmpl/ktabs.tmpl -o .meta/var/ktabs"
  kitty -o allow_remote_control=yes --detach bash -c "$(cat .meta/var/ktabs)"

# Run bash terminal inside container
bash:
  {{ this }} _shell bash

# Run zsh terminal inside container
@zsh:
  {{ this }} _shell zsh

_shell shell:
  @{{ this }} compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm -e SHELL={{ shell }} {{ container }} {{ shell }}

# Switch to AWS profile using aws-vault
profile profile="" +cmd="$SHELL":
  #!/bin/bash -eu
  exec {lock_fd}>/tmp/{{ file_name(invocation_directory()) }}.lock
  flock -x "$lock_fd"
  cd {{ invocation_directory() }}
  aws-vault exec --duration=8h \
    $({{ if profile != "" { "echo " + quote(profile) } else { this + " _gomplate \"-i '{{ index .config.awsVaultProfiles 0 }}' --exec-pipe -- tr -d '\r'\"" } }}) -- sh -c "flock -u $lock_fd; {{ cmd }}";

@_gomplate args:
  docker run --rm -v "{{ justfile_directory() }}:/src" -w /src -u $(id -u) hairyhenderson/gomplate:stable-alpine \
    -d global=.ws.config.yaml \
    $(test -e .ws.config.local.yaml && echo "-d local=.ws.config.local.yaml") \
    $(test -e .ws.config.local.yaml || echo "-d local=.ws.config.yaml") \
    -c "config=merge:local|global" \
    {{ args }}

# Install workspace to the project
install:
  @[ ! -L "{{ justfile_directory() }}/.meta" ] || (echo "Should be ran in the template itself" && false)
  {{ this }} init
  ln -fs {{ file_name(justfile_directory()) }}/.meta ../.meta
  -rm {{ justfile_directory() }}/.meta/.meta
  ln -fs {{ file_name(justfile_directory()) }}/config.yaml ../.ws.config.yaml
  ln -fs {{ file_name(justfile_directory()) }}/docker-compose.yml ../.ws.docker-compose.yml
  -ln -s {{ file_name(justfile_directory()) }}/.gitleaks.toml ../.gitleaks.toml
  ln -fs {{ file_name(justfile_directory()) }}/Justfile ../.ws.justfile
  -ln -fs ../{{ file_name(justfile_directory()) }}/.meta/idea/watcherTasks.xml ../.idea/watcherTasks.xml
  cd .. && git config core.excludesFile {{ file_name(justfile_directory()) }}/project.gitignore

# Pull changes and rebuild
update:
  #!/bin/bash -eu
  cd $(dirname $(readlink -f {{ quote(justfile()) }}))
  set -x
  git pull origin master
  {{ just }} install
  {{ this }} build
