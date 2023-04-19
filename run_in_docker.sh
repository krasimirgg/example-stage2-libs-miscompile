#!/bin/bash
set -eux

readonly IMAGE_NAME=stage2-libs-miscompile:latest

short=f
OPTS=$(getopt -o $short -- "$@")

eval set -- "${OPTS}"

declare -a build_args

while :; do
  case "$1" in
    -f ) build_args+=(--no-cache); shift ;;
    -- ) shift; break ;;
    * ) echo "unrecognized option $1"; exit 1 ;;
  esac
done

docker build "${build_args[@]}" -t "${IMAGE_NAME}" .
docker run -it "${IMAGE_NAME}" sh -c "cd workdir/rust; python3 x.py --color=never build --stage=2 library"
