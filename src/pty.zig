const std = @import("std");

const c = @cImport({
    @cInclude("pty.h");
    @cInclude("fcntl.h");
});

pub fn fdBlock(fd: std.posix.fd_t, block: bool) !void {
    const flags = try std.posix.fcntl(fd, c.F_GETFL, 0);
    if (block) {
        _ = try std.posix.fcntl(fd, c.F_SETFL, (flags | c.O_NONBLOCK) - c.O_NONBLOCK);
    } else {
        _ = try std.posix.fcntl(fd, c.F_SETFL, flags | c.O_NONBLOCK);
    }
}

pub fn forkpty() !struct{
    master: std.posix.fd_t,
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
        .master = master,
        .slave = @intCast(slave),
    };
}
