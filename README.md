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


Designing an API that provides "views" to manipulate binary packed data.

Brace yourself, this is kind of a long post.

I am working on a library for an industrial protocol called EtherCAT.

I am trying to reach MVP quickly and simply, and add frills later.

The library essentially is just for manipulating special bits that are sent over an 
ethernet port from the "main device" (linux computer) to subdevices arranges in a loop
topology. The Maindevice sends frames, they travel through the subdevices, the subdevices
write to and read from the frame, and then the frame returns to the maindevice.

I think the minimum workflow for the user is the following:

1. Write a "bus configuration" that describes the subdevices to be controlled
2. Write a while loop that repeatedly sends / recvs frames with binary data. Read the returned frame, do some logic,
send a modified frame, repeat.
