const std = @import("std");

const c = @cImport({
    @cInclude("pty.h");
});

pub fn forkpty() !struct{
    master: std.fs.File,
    slave: std.posix.fd_t,
} {
    var master: std.posix.fd_t = undefined;
    const slave = c.forkpty(
        @ptrCast(&master),
        null,
        null,
        null,
    );

    if (slave == -1) {
        return error.forkpty;
    }

    return .{
        .master = .{ .handle = master },
        .slave = @intCast(slave),
    };
}
