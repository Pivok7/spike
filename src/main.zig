const sdl3 = @import("sdl3");
const std = @import("std");
const colors = @import("colors.zig");
const pty = @import("pty.zig");
const shell = @import("shell.zig");
const GlyphMap = @import("GlyphMap.zig");

const Allocator = std.mem.Allocator;
const Colors = colors.Colors;

const default_font = @embedFile("fonts/Hack-Regular.ttf");
const default_font_size = 16.0;

const screen_width = 800;
const screen_height = 600;

const Cursor = struct {
    width: usize,
    height: usize,

    x: usize,
    y: usize,

    const Self = @This();

    pub fn new(width: usize, height: usize) Self {
        return .{
            .width = width,
            .height = height,
            .x = 0,
            .y = 0,
        };
    }

    pub fn next(self: *Self) void {
        self.x += 1;
    }

    pub fn newline(self: *Self) void {
        self.x = 0;
        self.y += 1;
    }

    pub fn move(self: *Self, x: usize, y: usize) void {
        self.x = x;
        self.y = y;
    }
};

fn slave(allocator: Allocator) !void {
    // Abandon hope all ye who enter here
    // Defers don't work here
    const args = [_:null]?[*:0]const u8{
        "bash".ptr,
        "--norc".ptr,
        null,
    };

    var envmap = try std.process.getEnvMap(allocator);
    try envmap.put("TERM", "dumb");

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
}

fn master(allocator: Allocator, fd: std.posix.fd_t) !void {
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
        .{ .resizable = true },
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

    var glyph_map = GlyphMap.init(allocator, font, renderer);
    defer glyph_map.deinit();

    var text_buffer = std.ArrayList(std.ArrayList(u8)){};
    defer {
        for (text_buffer.items) |*item| {
            item.deinit(allocator);
        }
        text_buffer.deinit(allocator);
    }
    try text_buffer.append(allocator, .{});

    try sdl3.keyboard.startTextInput(window);

    const glyph_zero = try glyph_map.getTexture(0x30) orelse return;
    var cursor = Cursor.new(
        glyph_zero.getWidth(),
        glyph_zero.getHeight()
    );

    var back_texture = try sdl3.render.Texture.init(
        renderer,
        .array_rgba_32,
        .target,
        1, 1,
    );
    defer back_texture.deinit();

    var quit = false;
    while (!quit) {
        while (sdl3.events.poll()) |e| {
            switch (e) {
                .quit => quit = true,
                .terminating => quit = true,
                .text_input => |input| {
                    try shell.write(input.text, fd);
                },
                .key_down => |keyboard| {
                    if (keyboard.key) |key| {
                        switch (key) {
                            .return_key => try shell.write("\n", fd),
                            .backspace => try shell.write("\x7F", fd),
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }

        const resized = try resizeTextureToWindow(
            window,
            renderer,
            &back_texture
        );

        if (try shell.read(allocator, &text_buffer, fd) or resized) {
            cursor.move(0, 0);

            _, const window_height = try window.getSize();
            const display_boundary = @divFloor(window_height, cursor.height) - 1;

            try renderer.setTarget(back_texture);
            try renderer.setDrawColor(Colors.black().toPixels());
            try renderer.clear();

            try renderer.setDrawColor(Colors.white().toPixels());

            for (text_buffer.items, 0..) |line, i| {
                if (i + display_boundary < text_buffer.items.len) continue;
                defer cursor.newline();

                var utf8_view = std.unicode.Utf8View.init(line.items) catch {
                    std.log.err("Invalid utf8", .{});
                    continue;
                };
                var utf8_iter = utf8_view.iterator();

                while (utf8_iter.nextCodepoint()) |c| {
                    defer cursor.next();

                    const texture = try glyph_map.getTexture(@intCast(c))
                        orelse continue;

                    try renderer.renderTexture(
                        texture,
                        null,
                        .{
                            .x = @floatFromInt(cursor.x * cursor.width),
                            .y = @floatFromInt(cursor.y * cursor.height),
                            .w = @floatFromInt(texture.getWidth()),
                            .h = @floatFromInt(texture.getHeight()),
                        }
                    );
                }
            }

            try renderer.setTarget(null);
        }

        try renderer.renderTexture(back_texture, null, null);
        try renderer.present();
    }

    try sdl3.keyboard.stopTextInput(window);
}

// Returns true if texture got resized
fn resizeTextureToWindow(
    window: sdl3.video.Window,
    renderer: sdl3.render.Renderer,
    texture: *sdl3.render.Texture
) !bool {
    const window_width, const window_height = try window.getSize();

    if (
        texture.getWidth() != window_width or
        texture.getHeight() != window_height
    ) {
        const old_texture_format = texture.getFormat() orelse {
            return error.NoTextureFormat;
        };
        const old_texture_access = (try texture.getProperties()).access
            orelse return error.NoTextureAccess;

        texture.deinit();
        texture.* = try sdl3.render.Texture.init(
            renderer,
            old_texture_format,
            old_texture_access,
            window_width,
            window_height,
        );

        return true;
    }

    return false;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();


    // PTY
    const res = try pty.forkpty();

    if (res.slave == 0) {
        try slave(allocator);
    } else {
        const fd = res.master;
        try pty.fdBlock(fd, false);
        try master(allocator, fd);
    }
}
