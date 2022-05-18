set dotenv-load := false
container := "workspace"
workdir := "/workspace"
just := quote(just_executable())
this := just + " -f " + quote(justfile())

# Show this help
help:
  @just --list --unsorted

init:
  pre-commit install
  docker -v
  docker-compose -v

git-cleanup:
  git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D

# Build/rebuild templates and docker image
build:
  {{ this }} _gomplate "-f .meta/tmpl/.env.tmpl -o .env"
  {{ this }} _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"
  cat .meta/var/Dockerfile \
    | grep -P "FROM .* as .*" \
    | sed 's/FROM .* as //' \
    | DOCKER_BUILDKIT=1 xargs -n1 -I {} docker build -t ws -f .meta/var/Dockerfile --target {} .
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build
  touch .meta/var/.bash_history

validate:
  {{ this }} _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"
  # cat .meta/var/Dockerfile | docker-compose run --rm {{ container }} hadolint -
  docker-compose run --rm {{ container }} pre-commit run

k profile="":
  @shell="{{ `just _gomplate "-i '{{ .config.shell }}' --exec-pipe -- tr -d '\r'"` }}" \
    && konsole -p tabtitle="{{ file_name(justfile_directory()) }}" --workdir "{{ invocation_directory() }}" -e \
    {{ if profile != "" { just + " profile " + quote(profile) } else { "" } }} {{ this }} "$shell" &

ks:
  {{ this }} _gomplate "-f .meta/tmpl/ktabs.tmpl -o .meta/var/ktabs"
  konsole --tabs-from-file .meta/var/ktabs -e true &

# Run bash terminal inside container
bash:
  {{ this }} _shell bash

# Run zsh terminal inside container
zsh:
  {{ this }} _shell zsh

_shell shell:
  @docker-compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm -e SHELL={{ shell }} {{ container }} zellij --session="${AWS_VAULT:-{{ shell }}}"

# Switch to AWS profile using aws-vault
profile profile="" +cmd="$SHELL":
  #!/bin/bash -eu
  exec {lock_fd}>/tmp/{{ file_name(invocation_directory()) }}.lock
  flock -x "$lock_fd"
  cd {{ invocation_directory() }}
  aws-vault exec --duration=8h \
    {{ if profile != "" { profile } else { `just _gomplate "-i '{{ index .config.awsVaultProfiles 0 }}' --exec-pipe -- tr -d '\r'"` } }} -- sh -c "flock -u $lock_fd; {{ cmd }}";

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
  -ln -fs ../{{ file_name(justfile_directory()) }}/.meta/idea/watcherTasks.xml ../.idea/watcherTasks.xml
  cd .. && git config core.excludesFile {{ file_name(justfile_directory()) }}/project.gitignore

update:
  #!/bin/bash -eu
  cd $(dirname $(readlink -f {{ quote(justfile()) }}))
  set -x
  git pull origin master
  {{ this }} install
  {{ this }} ../build

ws +args:
  {{ just }} -f {{ quote(invocation_directory() + "/.ws.justfile") }} {{ args }}
