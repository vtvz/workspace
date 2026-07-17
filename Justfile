set dotenv-load := false
set positional-arguments

container := "workspace"
workdir := "/workspace"
just := quote(just_executable())
this := just + " -f " + quote(justfile())

# Recipe prefix for self-invocations: "ws::" when loaded as a module, "" standalone
ns := if module_path() == "" { "" } else { module_path() + "::" }

# Show this help
@help:
  {{ this }} --list --unsorted

[no-cd]
init:
  docker -v
  docker-compose -v

# Removes branches without remote
[no-cd]
git-cleanup:
  git fetch -p && git branch --format='%(refname:short)%09%(upstream:track)' | grep -e '\[gone\]$' | awk '{print $1}' | xargs git branch -D

# Build/rebuild templates and docker image
[no-cd]
build:
  {{ this }} {{ ns }}build-dotenv
  {{ this }} {{ ns }}build-dockerfile
  {{ this }} {{ ns }}compose build

[no-cd]
build-till-success:
  until {{ this }} {{ ns }}build; do sleep 1; done

[no-cd, private]
build-dockerfile:
  {{ this }} {{ ns }}gomplate "-f .ws/templates/Dockerfile.tmpl -o .ws/var/Dockerfile"

[no-cd]
build-dotenv:
  {{ this }} {{ ns }}gomplate "-f .ws/templates/.env.tmpl -o .ws.env"

[no-cd, private]
@compose *args:
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 BUILDX_BUILDER=${BUILDX_BUILDER:-default} docker-compose --project-directory {{ invocation_directory() }} -f .ws/docker-compose.yml {{ args }}

[no-cd]
validate:
  {{ this }} {{ ns }}build-dockerfile
  -cat .ws/var/Dockerfile | {{ this }} {{ ns }}compose run --rm -T {{ container }} hadolint -

alias sh := shell

# Run zsh terminal inside container
[no-cd]
shell:
  @{{ this }} {{ ns }}compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm -e SHELL=zsh {{ container }} zsh

# Switch to AWS profile using aws-vault
[no-cd]
profile profile +cmd="$SHELL":
  #!/bin/bash -eu
  exec {lock_fd}>/tmp/{{ file_name(invocation_directory()) }}.lock
  flock -x "$lock_fd"
  cd {{ invocation_directory() }}
  aws-vault exec --duration=8h \
    {{ quote(profile) }} -- sh -c "flock -u $lock_fd; {{ cmd }}";

# Run zsh in AWS profile
[no-cd]
psh profile:
  @{{ this }} {{ ns }}profile {{ quote(profile) }} {{ this }} {{ ns }}shell

[no-cd, private]
@gomplate args:
  docker run --rm -v "{{ justfile_directory() }}:/src" -w /src -u $(id -u) hairyhenderson/gomplate:stable-alpine \
    -d global=.ws/config.yaml \
    $(test -e .ws.config.yaml && echo "-d local=.ws.config.yaml") \
    $(test -e .ws.config.yaml || echo "-d local=.ws/config.yaml") \
    -c "config=merge:local|global" \
    {{ args }}

# Install workspace to the project
[no-cd]
install:
  @[ ! -L "{{ justfile_directory() }}/.ws" ] || (echo "Should be ran in the project itself" && false)
  {{ this }} {{ ns }}init
  -ln -s {{ file_name(justfile_directory()) }}/.gitleaks.toml ../.gitleaks.toml
  touch {{ justfile_directory() }}/.env
  cp -f {{ justfile_directory() }}/.ws/tools/.tflint.hcl {{ quote(home_directory() + "/.tflint.hcl") }}
  git config core.excludesFile .ws/project.gitignore

# Pull changes and rebuild
[no-cd]
update:
  #!/bin/bash -eu
  cd .ws
  set -x
  git pull origin master
  cd ..
  {{ this }} {{ ns }}install
  {{ this }} {{ ns }}build
