const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BAD002;
const FLAGS = ALIGN | MEMINFO;

const MultibootHeader = struct {
    magic: i32 = MAGIC,
    flags: i32,
    checksum: i32,
};

var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
const stack_bytes_slice = stack_bytes[0..];

export fn _start() noreturn {
    const mbinfo_addr: usize align(16) =
        asm volatile (""
        : [ret] "={ebx}" (-> usize),
    );

    kmain(@ptrFromInt(mbinfo_addr));

    asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

fn kmain(_info: *const MultibootHeader) void {
    _ = _info; // autofix
}
