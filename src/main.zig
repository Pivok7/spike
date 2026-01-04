const sdl3 = @import("sdl3");
const std = @import("std");
const colors = @import("colors.zig");
const pty = @import("pty.zig");

const Allocator = std.mem.Allocator;
const Colors = colors.Colors;

const default_font = @embedFile("fonts/Hack-Regular.ttf");
const default_font_size = 16.0;

const screen_width = 800;
const screen_height = 600;

fn shell(allocator: Allocator, fd: std.fs.File) ![]const u8 {
    var fs_writer = fd.writer(&[_]u8{});
    const writer = &fs_writer.interface;

    var arr = std.ArrayList(u8){};
    defer arr.deinit(allocator);

    var buf: [1024]u8 = undefined;
    var fs_reader = fd.reader(&buf);
    const reader = &fs_reader.interface;

    while (true) {
        const b = reader.takeByte() catch break;
        try arr.append(allocator, b);
        if (b == '$') break;
    }

    try writer.writeAll("ls\n");
    try writer.flush();

    while (true) {
        const b = reader.takeByte() catch break;
        try arr.append(allocator, b);
        if (b == '$') break;
    }

    return try arr.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    defer sdl3.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    try sdl3.ttf.init();
    defer sdl3.ttf.quit();

    // Initial window setup.
    const window = try sdl3.video.Window.init(
        "Spike",
        screen_width,
        screen_height,
        .{
            .resizable = true
        },
    );
    defer window.deinit();

    const renderer = try sdl3.render.Renderer.init(window, null);
    defer renderer.deinit();

    try renderer.setVSync(.{ .on_each_num_refresh = 1 });

    const font = try sdl3.ttf.Font.initFromIO(
        try .initFromConstMem(default_font),
        true,
        default_font_size,
    );
    defer font.deinit();

    // PTY
    const res = try pty.forkpty();

    if (res.slave == 0) {
        const args = [_:null]?[*:0]const u8{
            "bash".ptr,
            null,
        };

        var envmap = try std.process.getEnvMap(allocator);
        defer envmap.deinit();

        const env = [_:null]?[*:0]const u8{
            null,
        };

        std.posix.execvpeZ(
            args[0].?,
            &args,
            &env
        ) catch {};
    } else {
        const shell_output = try shell(allocator, res.master);

        var text_arr = std.ArrayList(sdl3.render.Texture){};
        defer {
            for (text_arr.items) |text| {
                text.deinit();
            }
            text_arr.deinit(allocator);
        }

        var iter = std.mem.splitScalar(u8, shell_output, '\n');
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            const surface = try font.renderTextBlended(line, Colors.white().toTTF());
            const texture = try renderer.createTextureFromSurface(surface);
            surface.deinit();

            std.debug.print("{s}\n", .{line});
            try text_arr.append(allocator, texture);
        }

        allocator.free(shell_output);

        var quit = false;
        while (!quit) {
            // Render
            try renderer.setDrawColor(Colors.black().toPixels());
            try renderer.clear();

            for (text_arr.items, 0..) |text, i| {
                try renderer.renderTexture(
                    text,
                    null,
                    .{
                        .x = 0.0,
                        .y = 0.0 + @as(f32, @floatFromInt(i)) * @as(f32, @floatFromInt(text.getHeight())),
                        .w = @floatFromInt(text.getWidth()),
                        .h = @floatFromInt(text.getHeight()),
                    }
                );
            }

            try renderer.present();

            // Event logic.
            while (sdl3.events.poll()) |event|
                switch (event) {
                    .quit => quit = true,
                    .terminating => quit = true,
                    else => {},
                };
        }
    }
}
