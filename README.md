# example-stage2-libs-miscompile
repro for stage2 stdlibs miscompile after https://github.com/llvm/llvm-project/commit/6f7e5c0f1ac6cc3349a2e1479ac4208465b272c6

To repro:
```
./run_in_docker.sh
```
That builds rust + llvm @ 6f7e5c0f1ac6cc3349a2e1479ac4208465b272c6 and runs the failing stage2 library build.

Errors look like build.log.
