# Workspace

A handy tools for your daily DevOps routine.

## Prerequisite

- [docker](https://docs.docker.com/engine/install/)
- [docker-compose](https://docs.docker.com/compose/install/)
- [just](https://github.com/casey/just#installation)

## Install

### Add this to your Justfile

```justfile
set positional-arguments

just := quote(just_executable())

ws *args:
  {{ just }} -f {{ quote(join(justfile_directory(), ".ws.justfile")) }} "$@"
```

### Run these commands

```shell
git clone https://github.com/vtvz/workspace.git .ws
# git clone git@github.com:vtvz/workspace.git .ws
just .ws/install
just build
just profile [your aws-vault profile name] #optional
just zsh
```
