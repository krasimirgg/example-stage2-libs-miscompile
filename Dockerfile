FROM ubuntu:focal

RUN apt-get update
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin
RUN apt-get install -y \
  cmake \
  ninja-build \
  tzdata \
  build-essential \
  curl \
  git \
  wget \
  rsync \
  python3 \
  gdb \
  lld

RUN (git config --global user.email "nobody@example.com")
RUN (git config --global user.email "Mister Nobody the Robot")

WORKDIR /example
ADD rull.sh /example
ADD config.toml /example
ADD subtarget_info.patch /example
ADD run.sh /example

ARG RUST_REF=master
ARG LLVM_REF=6f7e5c0f1ac6cc3349a2e1479ac4208465b272c6

RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --until=rust.cloned)
RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --until=rust.submodule_updated)
RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --until=llvm.fetched)
RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --until=llvmrust.inited)
RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --until=rust.built)

RUN (./rull.sh --rustrev=$RUST_REF --llvmrev=$LLVM_REF --cmd='python3 x.py build --stage=2 library')
CMD (cd rust; python3 x.py build --stage=2 library)
