const std = @import("std");

const Allocator = std.mem.Allocator;

// TODO: Remove me later!
var mirror_shell: bool = false;

pub fn write(
    string: []const u8,
    fd: std.posix.fd_t,
) !void {
    var written: usize = 0;

    while (written < string.len) {
        const w = try std.posix.write(
            fd,
            string[written..],
        );
        written += w;
    }
}

pub fn read(
    allocator: Allocator,
    buf: *std.ArrayList(std.ArrayList(u8)),
    fd: std.posix.fd_t,
) !bool {
    var read_anything: bool = false;
    var rbuf: [4096]u8 = undefined;

    while (true) {
        const rlen = std.posix.read(fd, &rbuf) catch break;
        const r = rbuf[0..rlen];

        if (mirror_shell) {
            std.debug.print("{s}", .{r});
        }

        if (rlen > 0) read_anything = true;

        for (r) |c| {
            const buf_end = &buf.items[buf.items.len - 1];
            // Check 'line feed' or 'carriage return'
            if (c == '\x09') {
                std.debug.print("fsdko\n", .{});
            }
            if (c == '\x0a') {
                try buf.append(allocator, .{});
                continue;
            }
            // TODO: Check this
            //if (c == '\x0d') continue;
            // Backspace

            if (c == '\x08') {
                const last = buf_end.pop() orelse break;
                _ = std.unicode.utf8ByteSequenceLength(last) catch {
                    try write("\x7F", fd);
                };
                continue;
            }
            try buf_end.append(allocator, c);
        }
    }

    return read_anything;
}
