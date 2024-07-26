set dotenv-load := false
set positional-arguments

container := "workspace"
workdir := "/workspace"
just := quote(just_executable())
this := just + " -f " + quote(justfile())

# Show this help
@help:
  {{ this }} --list --unsorted

[no-cd]
init:
  -pre-commit install --allow-missing-config
  docker -v
  docker-compose -v

# Removes branches without remote
[no-cd]
git-cleanup:
  git fetch -p && git branch --format='%(refname:short)%09%(upstream:track)' | grep -e '\[gone\]$' | awk '{print $1}' | xargs git branch -D

# nuild/rebuild templates and docker image
[no-cd]
build prebuild='false':
  {{ this }} ws::build-dotenv
  {{ this }} ws::build-dockerfile
  if [[ {{ quote(prebuild) }} == "true" ]]; then \
    cat .ws/var/Dockerfile \
      | grep -P "^FROM .* AS .*" \
      | sed 's/FROM .* AS //' \
      | DOCKER_BUILDKIT=1 xargs -n1 -I {} docker build -t ws -f .ws/var/Dockerfile --target {} .; \
  fi

  if [[ {{ quote(prebuild) }} != "true" ]] || [[ {{ quote(prebuild) }} != "false" ]]; then \
    DOCKER_BUILDKIT=1 docker build -t ws -f .ws/var/Dockerfile --target {{ prebuild }} .; \
  else \
    {{ this }} ws::compose build; \
  fi

[no-cd, private]
build-dockerfile:
  {{ this }} ws gomplate "-f .ws/templates/Dockerfile.tmpl -o .ws/var/Dockerfile"

[no-cd]
build-dotenv:
  {{ this }} ws gomplate "-f .ws/templates/.env.tmpl -o .ws.env"

[no-cd, private]
@compose *args:
  COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose --project-directory {{ invocation_directory() }} -f .ws/docker-compose.yml {{ args }}

[no-cd]
validate:
  {{ this }} ws::build-dockerfile
  -cat .ws/var/Dockerfile | {{ this }} ws::compose run --rm -T {{ container }} hadolint -
  -{{ this }} ws::compose run --rm {{ container }} pre-commit run

# Run zsh terminal inside container
[no-cd]
shell:
  {{ this }} ws::compose run -w {{ workdir }}/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm -e SHELL=zsh {{ container }} zsh

# Switch to AWS profile using aws-vault
[no-cd]
profile profile="" +cmd="$SHELL":
  #!/bin/bash -eu
  exec {lock_fd}>/tmp/{{ file_name(invocation_directory()) }}.lock
  flock -x "$lock_fd"
  cd {{ invocation_directory() }}
  aws-vault exec --duration=8h \
    $({{ if profile != "" { "echo " + quote(profile) } else { this + " ws gomplate \"-i '{{ index .config.awsVaultProfiles 0 }}' --exec-pipe -- tr -d '\r'\"" } }}) -- sh -c "flock -u $lock_fd; {{ cmd }}";

# Run zsh in AWS profile
[no-cd]
psh profile="":
  {{ this }} ws::profile {{ quote(profile) }} {{ this }} ws::shell

[no-cd]
profiles:
  {{ this + " ws gomplate \"-i '{{ .config.awsVaultProfiles | toJSON }}' --exec-pipe -- tr -d '\r'\"" }}

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
  {{ this }} ws::init
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
  {{ just }} ws::install
  {{ this }} ws::build
