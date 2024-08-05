

zig annoyances

1. Cannot tell if my tests have run or not (even with --summary all)
2. Packed structs are not well described in the language reference



zig wins

big endian archs tests:

1. sudo apt install qemu-system-ppc qemu-utils binfmt-support qemu-user-static
2. zig build -fqemu -Dtarget=powerpc64-linux test --summary all