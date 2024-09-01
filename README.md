# Zig EtherCAT MainDevice

An EtherCAT MainDevice written in pure Zig.

This library is in extremely early development.



## Notes

### zig annoyances

1. Cannot tell if my tests have run or not (even with --summary all)
2. Packed structs are not well described in the language reference
3. Where to I look for the implementation of flags.parse? root.zig? I don't know where
anything is!
4. Cannot have arrays in packed structs. (See SM and FMMU structs).
5. For loops over slices / arrays: I have to loop up the syntax every time.

### zig wins

big endian archs tests:

1. sudo apt install qemu-system-ppc qemu-utils binfmt-support qemu-user-static
2. zig build -fqemu -Dtarget=powerpc64-linux test --summary all


