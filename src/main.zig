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

// TODO: Remove me later!
var mirror_shell: bool = false;

fn shellWrite(
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

fn shellRead(
    allocator: Allocator,
    buf: *std.ArrayList(std.ArrayList(u8)),
    fd: std.posix.fd_t,
) !bool {
    var read_anything: bool = false;
    var rbuf: [4096]u8 = undefined;

    while (true) {
        const rlen = std.posix.read(fd, &rbuf) catch break;
        const read = rbuf[0..rlen];

        if (mirror_shell) {
            std.debug.print("{s}", .{read});
        }

        if (rlen > 0) read_anything = true;

        for (read) |c| {
            const buf_end = &buf.items[buf.items.len - 1];
            // Check 'line feed' or 'carriage return'
            if (c == '\x0a') {
                try buf.append(allocator, .{});
                continue;
            }
            // TODO: Check this
            if (c == '\x0d') continue;
            // Backspace
            if (c == '\x08') {
                _ = buf_end.pop();
                continue;
            }
            try buf_end.append(allocator, c);
        }
    }

    return read_anything;
}

fn genText(
    allocator: Allocator,
    font: sdl3.ttf.Font,
    renderer: sdl3.render.Renderer,
    text_buf: *std.ArrayList(std.ArrayList(u8)),
    textures: *std.ArrayList(sdl3.render.Texture),
) !void {
    for (textures.items) |line| {
        line.deinit();
    }
    textures.clearAndFree(allocator);

    const boundary = text_buf.items.len - @min(32, text_buf.items.len);

    for (text_buf.items[boundary..]) |*line| {
        if (line.items.len == 0) continue;
        const surface = try font.renderTextBlended(line.items, Colors.white().toTTF());
        const texture = try renderer.createTextureFromSurface(surface);
        surface.deinit();

        try textures.append(allocator, texture);
    }
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
            "--norc".ptr,
            null,
        };

        var envmap = try std.process.getEnvMap(allocator);
        const env = try std.process.createNullDelimitedEnvMap(
            allocator,
            &envmap,
        );
        envmap.deinit();

        std.posix.execvpeZ(
            args[0].?,
            &args,
            env
        ) catch {};
    } else {
        const fd = res.master;
        try pty.fdBlock(fd, false);

        var text_buffer = std.ArrayList(std.ArrayList(u8)){};
        defer {
            for (text_buffer.items) |*item| {
                item.deinit(allocator);
            }
            text_buffer.deinit(allocator);
        }
        try text_buffer.append(allocator, .{});

        var text_arr = std.ArrayList(sdl3.render.Texture){};
        defer {
            for (text_arr.items) |text| {
                text.deinit();
            }
            text_arr.deinit(allocator);
        }

        try sdl3.keyboard.startTextInput(window);

        var quit = false;
        while (!quit) {
            while (sdl3.events.poll()) |e| {
                switch (e) {
                    .quit => quit = true,
                    .terminating => quit = true,
                    .text_input => |input| {
                        try shellWrite(input.text, fd);
                    },
                    .key_down => |keyboard| {
                        if (keyboard.key) |key| {
                            switch (key) {
                                .escape => quit = true,
                                .return_key => try shellWrite("\n", fd),
                                .backspace => try shellWrite("\x7F", fd),
                                else => {},
                            }
                        }
                    },
                    else => {},
                }
            }

            if (try shellRead(allocator, &text_buffer, fd)) {
                try genText(
                    allocator,
                    font,
                    renderer,
                    &text_buffer,
                    &text_arr,
                );
            }

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
        }

        try sdl3.keyboard.stopTextInput(window);
    }
}
