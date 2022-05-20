# Workspace

A handy tools for your daily DevOps routine.

## Prerequisite

- [docker](https://docs.docker.com/engine/install/)
- [docker-compose](https://docs.docker.com/compose/install/)
- [just](https://github.com/casey/just#installation)

## Install

```shell
git clone https://github.com/vtvz/workspace.git .ws
# git clone git@github.com:vtvz/workspace.git .ws
just .ws/install
just build
just profile [your aws-vault profile name] #optional
just zsh
```
