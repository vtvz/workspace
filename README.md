# Workspace

A handy tools for your daily DevOps routine.

## Prerequisite

- [docker](https://docs.docker.com/engine/install/)
- [docker-compose](https://docs.docker.com/compose/install/)
- [just](https://github.com/casey/just#installation)

## Install

### Add this to your zshrc or bashrc

```bash
export JUST_UNSTABLE=true
```

### Add this to your Justfile

```justfile
!include .ws/Justfile

set positional-arguments
```

### Run these commands

```shell
git clone git@github.com:vtvz/workspace.git .ws
# git clone https://github.com/vtvz/workspace.git .ws
just ws-install
just ws-build
just profile [your aws-vault profile name] #optional
just shell
```
