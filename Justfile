set dotenv-load := false

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
  docker-compose build

validate:
  just _gomplate "-f .meta/tmpl/Dockerfile.tmpl -o .meta/var/Dockerfile"
  cat .meta/var/Dockerfile | docker-compose run --rm terraform hadolint -
  docker-compose run --rm terraform pre-commit run

# Run bash terminal inside container
sh:
  docker-compose run -w /terraform/`realpath --relative-to={{ justfile_directory() }} {{ invocation_directory() }}` --rm terraform bash

# Switch to AWS profile using aws-vault
profile profile="":
  cd {{ invocation_directory() }} \
    && aws-vault exec --duration=8h \
    {{ if profile != "" { profile } else { `just _gomplate "-i '{{ .config.awsVaultProfile }}' --exec-pipe -- tr -d '\r'"` } }}

_gomplate args:
  @docker-compose -p gomplate --project-directory . -f .meta/docker-compose.yml run --rm gomplate \
    -d global=config.yaml \
    `test -e config.local.yaml && echo "-d local=config.local.yaml"` \
    `test -e config.local.yaml || echo "-d local=config.yaml"` \
    -c "config=merge:local|global" \
    {{ args }}

# Upgrade terraform to another version. Version from config.yaml taken by default. You can pass the second param to manually specify the version
terraform_upgrade version=`just _gomplate "-i '{{ index .config.tools \"hashicorp/terraform\" }}' --exec-pipe -- tr -d '\r'"`:
  #!/bin/bash -xe
  RESULT=0;
  docker-compose run terraform bash -ec " \
    grep 'hashicorp/terraform: {{ version }}' config.yaml; \
    grep 'required_version = \"{{ version }}\"' projects/provider.tf.global; \
    grep 'TERRAFORM_VERSION={{ version }}' .travis.yml; \
  " || RESULT=$?;

  docker-compose run terraform bash -ec " \
    sed -i 's|hashicorp/terraform: .*|hashicorp/terraform: {{ version }}|g' config.yaml; \
    sed -i 's|required_version = ".*"|required_version = \"{{ version }}\"|g' projects/provider.tf.global; \
    sed -i 's|TERRAFORM_VERSION=.*|TERRAFORM_VERSION={{ version }}|g' .travis.yml; \
  ";

  exit $RESULT;

# Install workspace to the project
install:
  @[ ! -L "{{ justfile_directory() }}/.meta" ] || (echo "Should be ran in the template itself" && false)
  ln -fs {{ file_name(justfile_directory()) }}/.meta ../.meta
  -rm {{ justfile_directory() }}/.meta/.meta
  ln -fs {{ file_name(justfile_directory()) }}/config.yaml ../config.yaml
  ln -fs {{ file_name(justfile_directory()) }}/docker-compose.yml ../docker-compose.yml
  ln -fs {{ file_name(justfile_directory()) }}/Justfile ../Justfile
