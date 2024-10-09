//! Process Data Image
//!
//! The process data image is the logical memory address space. Subdevices can read from and write to
//! the address space. The FMMUs in each subdevice govern the translation of the logical memory
//! address space to the physical memory address space and vice-versa.

pub const Direction = enum {
    /// subdevice writes data to image
    input,
    /// maindevice writes data to image
    output,
};
