set dotenv-load := false


container := "workspace"
workdir := "/workspace"
just := quote(just_executable())
this := just + " -f " + quote(justfile())

# Show this help
@help:
  {{ this }} --list --unsorted

ws-init:
  -pre-commit install --allow-missing-config
  docker -v
  docker-compose -v

# Removes branches without remote
git-cleanup:
  git fetch -p && git branch --format='%(refname:short)%09%(upstream:track)' | grep -e '\[gone\]$' | awk '{print $1}' | xargs git branch -D

# nuild/rebuild templates and docker image
ws-build prebuild='false':
  {{ this }} ws-build-dotenv
  {{ this }} _ws-build-dockerfile
  {{ if prebuild == 'false' { 'true' } else { 'false' } }} || cat .ws/var/Dockerfile \
    | grep -P "^FROM .* as .*" \
    | sed 's/FROM .* as //' \
    | DOCKER_BUILDKIT=1 xargs -n1 -I {} docker build -t ws -f .ws/var/Dockerfile --target {} .
  {{ this }} compose build

@_ws-build-dockerfile:
  {{ this }} _ws-gomplate "-f .ws/meta/tmpl/Dockerfile.tmpl -o .ws/var/Dockerfile"

ws-build-dotenv:
  {{ this }} _ws-gomplate "-f .ws/meta/tmpl/.env.tmpl -o .ws.env"

@compose *args:
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose --project-directory {{ invocation_directory() }} -f .ws/docker-compose.yml {{ args }}

validate:
  {{ this }} _build-dockerfile
  cat .ws/var/Dockerfile | {{ this }} compose run --rm -T {{ container }} hadolint -
  {{ this }} compose run --rm {{ container }} pre-commit run

# Run zsh terminal inside container
shell:
  @{{ this }} compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm -e SHELL=zsh {{ container }} zsh

# Switch to AWS profile using aws-vault
profile profile="" +cmd="$SHELL":
  #!/bin/bash -eu
  exec {lock_fd}>/tmp/{{ file_name(invocation_directory()) }}.lock
  flock -x "$lock_fd"
  cd {{ invocation_directory() }}
  aws-vault exec --duration=8h \
    $({{ if profile != "" { "echo " + quote(profile) } else { this + " _ws-gomplate \"-i '{{ index .config.awsVaultProfiles 0 }}' --exec-pipe -- tr -d '\r'\"" } }}) -- sh -c "flock -u $lock_fd; {{ cmd }}";

profiles:
  {{ this + " _ws-gomplate \"-i '{{ .config.awsVaultProfiles | toJSON }}' --exec-pipe -- tr -d '\r'\"" }}

@_ws-gomplate args:
  docker run --rm -v "{{ justfile_directory() }}:/src" -w /src -u $(id -u) hairyhenderson/gomplate:stable-alpine \
    -d global=.ws/config.yaml \
    $(test -e .ws.config.yaml && echo "-d local=.ws.config.yaml") \
    $(test -e .ws.config.yaml || echo "-d local=.ws/config.yaml") \
    -c "config=merge:local|global" \
    {{ args }}

# Install workspace to the project
ws-install:
  @[ ! -L "{{ justfile_directory() }}/.ws" ] || (echo "Should be ran in the project itself" && false)
  {{ this }} ws-init
  -ln -s {{ file_name(justfile_directory()) }}/.gitleaks.toml ../.gitleaks.toml
  touch {{ file_name(justfile_directory()) }}
  cp -f {{ justfile_directory() }}/.ws/meta/.tflint.hcl ~/.tflint.hcl
  git config core.excludesFile .ws/project.gitignore

# Pull changes and rebuild
ws-update:
  #!/bin/bash -eu
  cd $(dirname $(readlink -f {{ quote(justfile()) }}))
  set -x
  git pull origin master
  {{ just }} ws-install
  {{ this }} ws-build
