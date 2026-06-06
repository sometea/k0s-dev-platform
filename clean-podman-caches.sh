#!/bin/sh
podman system df
podman system prune -a --volumes
podman system df
