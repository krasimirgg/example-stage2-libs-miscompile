#!/bin/bash
set -eu

short=vfu:
long=verbose,force,until:,llvmrev:,rustrev:,cmd:
OPTS=$(getopt -o $short --long $long -- "$@")

eval set -- "${OPTS}"

rustrev=master
llvmrev=main
until_file=""
force=0
cmd=""

while :; do
  case "$1" in
    -v | --verbose ) set -x; shift 1 ;;
    -f | --force ) force=1; shift 1 ;;
    -u | --until ) until_file=$2; shift 2 ;;
    --llvmrev ) llvmrev=$2; shift 2 ;;
    --rustrev ) rustrev=$2; shift 2 ;;
    --cmd ) cmd="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) echo 'error parsing options'; exit 1 ;;
  esac
done

readonly RUNDIR=$(dirname "$(readlink -f "$BASH_SOURCE")")
readonly WORKDIR="${RUNDIR}/workdir"


init_workdir() {
  if (( $force )); then
    echo "clearing ${WORKDIR}"
    rm -rf "${WORKDIR}"
  fi
  mkdir -p "${WORKDIR}"
}

clone_rust() {
  cd "${WORKDIR}"
  local rust_cloned="${WORKDIR}/rust.cloned"
  if [[ ! -f "${rust_cloned}" ]]; then
    echo "cloning rust"
    git clone https://github.com/rust-lang/rust 
    touch "${rust_cloned}"
  fi
}

submodule_update_rust() {
  cd "${WORKDIR}"
  local rust_submodule_updated="${WORKDIR}/rust.submodule_updated"
  if [[ ! -f "${rust_submodule_updated}" ]]; then
    echo "updating rust submodules"
    cd rust
    git submodule update --init --recursive
    touch "${rust_submodule_updated}"
  fi
}

copy_config() {
  cd "${WORKDIR}/rust"
  cp "${RUNDIR}/config.toml" .
}

fetch_llvm_main() {
  cd "${WORKDIR}"
  local llvm_inited="${WORKDIR}/llvm.fetched"
  if [[ ! -f "${llvm_inited}" ]]; then
    echo "updating llvm from main"
    cd rust/src/llvm-project
    if [ "$(git remote | grep llvm | wc -l)" -eq "0" ]; then
      git remote add llvm https://github.com/llvm/llvm-project
      git fetch llvm
    fi
    touch "${llvm_inited}"
  fi
}

init_llvmrust() {
  cd "${WORKDIR}"
  local llvmrust_inited="${WORKDIR}/llvmrust.inited"
  if [[ ! -f "${llvmrust_inited}" ]]; then
    echo "initing llvmrust branch"
    cd rust/src/llvm-project
    git checkout $llvmrev
    git checkout -b llvmrust || git checkout llvmrust
    touch "${llvmrust_inited}"
  fi
}

apply_subtarget_info_patch() {
  cd "${WORKDIR}"
  local subtarget_info_patch_applied="${WORKDIR}/subtarget_info_patch.applied"
  if [[ ! -f "${subtarget_info_patch_applied}" ]]; then
    echo "applying subtarget info patch"
    cd rust/src/llvm-project
    patch -p1 <"${RUNDIR}/subtarget_info.patch"
    git add .
    git commit -m "subtarget info patch"
    echo "$(git rev-parse HEAD)" > "${subtarget_info_patch_applied}"
  fi
}

rust_rev() {
  cd "${WORKDIR}"
  cd rust
  readonly RUST_BRANCH="$(git branch)"
  readonly RUST_COMMIT="$(git rev-parse HEAD)"
  echo "Built Rust using:"
  echo "    branch: $RUST_BRANCH"
  echo "    commit: $RUST_COMMIT"
}

llvm_rev() {
  cd "${WORKDIR}"
  cd rust/src/llvm-project
  readonly LLVM_BRANCH="$(git branch)"
  readonly LLVM_COMMIT="$(git rev-parse HEAD~)"
  echo "Built LLVM using:"
  echo "    branch: $LLVM_BRANCH"
  echo "    commit: $LLVM_COMMIT"
}

update_rust() {
  cd "${WORKDIR}"
  cd rust
  local new_rust="$(git rev-parse $rustrev)"
  if [[ "${RUST_COMMIT}" != "${new_rust}" ]]; then
    echo "updating rust to ${new_rust}"
    git checkout "${new_rust}"
  fi
}

update_llvm() {
  cd "${WORKDIR}"
  local llvm_built="${WORKDIR}/llvm.built"
  local subtarget_info_patch_applied="${WORKDIR}/subtarget_info_patch.applied"
  if [[ ! -f "${llvm_built}" ]]; then
    local llvm_built_rev=none
  else
    local llvm_built_rev="$(<$llvm_built)"
  fi
  echo "previously built llvm revision: $llvm_built_rev"

  cd rust/src/llvm-project
  local new_llvm="$(git rev-parse $llvmrev)"

  if [[ "${LLVM_COMMIT}" != "${new_llvm}" ]]; then
    echo "updating llvm to ${new_llvm}"
    git rebase llvmrust --onto "${new_llvm}"
    git cherry-pick "$(cat $subtarget_info_patch_applied)"
    echo "${new_llvm}" > $llvm_built
  fi
}

build_rust() {
  cd "${WORKDIR}"
  local rust_built="${WORKDIR}/rust.built"
  local rust_built_out="${WORKDIR}/rust.built.out"

  if [[ ! -f "${rust_built}" ]]; then
    local rust_built_rev=none
  else
    local rust_built_rev="$(<$rust_built)"
  fi

  echo "previously built rust revision: $rust_built_rev"


  if [[ "${RUST_COMMIT}" != "${rust_built_rev}" ]]; then
    echo "building rust at ${RUST_COMMIT}"
    cd rust
    python3 x.py build 2>&1 | tee "${rust_built}"
  fi
}

run_cmd() {
  if [[ ! -z "${cmd}" ]]; then
    echo "running ${cmd}"
    cd "${WORKDIR}"
    local cmd_out="${WORKDIR}/cmd.out"
    sh -c "cd $WORKDIR/rust; $cmd" 2>&1 | tee "${cmd_out}"
  fi
}

maybe_exit() {
  cd "${WORKDIR}"

  if [[ -f "${until_file}" ]]; then
    echo "found ${WORKDIR}/${until_file}; exiting"
    exit 0
  fi
}

main () {
  init_workdir
  clone_rust; maybe_exit
  rust_rev
  update_rust
  submodule_update_rust; maybe_exit
  copy_config
  fetch_llvm_main; maybe_exit
  init_llvmrust; maybe_exit
  apply_subtarget_info_patch; maybe_exit
  llvm_rev
  update_llvm
  update_rust
  build_rust; maybe_exit
  run_cmd
}

main
