const sdl3 = @import("sdl3");
const std = @import("std");
const colors = @import("colors.zig");

const Allocator = std.mem.Allocator;
const Colors = colors.Colors;

const default_font = @embedFile("fonts/Hack-Regular.ttf");
const default_font_size = 16.0;

const screen_width = 800;
const screen_height = 600;

fn shell(allocator: Allocator) ![]const u8 {
    // Init terminal

    var a = std.process.Child.init(&[_][]const u8{
        "bash"
    }, allocator);
    a.stdout_behavior = .Pipe;
    a.stdin_behavior = .Pipe;
    a.stderr_behavior = .Pipe;
    try a.spawn();

    var rbuf: [1]u8 = undefined;
    var r = a.stdout.?.reader(&rbuf);
    const rr = &r.interface;

    var w = a.stdin.?.writer(&.{});
    const ww = &w.interface;

    try ww.writeAll("pwd\n");
    try ww.writeAll("exit\n");

    var arr = std.ArrayList(u8){};

    while (true) {
        const b = rr.takeByte() catch break;
        try arr.append(allocator, b);
    }

    a.stdin = null;
    a.stdout = null;
    a.stderr = null;
    _ = try a.kill();

    std.debug.print("{s}", .{arr.items});

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

    const shell_output = try shell(allocator);

    const text = try font.renderTextBlended(shell_output, Colors.white().toTTF());
    allocator.free(shell_output);

    const texture_text = try renderer.createTextureFromSurface(text);
    defer texture_text.deinit();

    text.deinit();

    var quit = false;
    while (!quit) {
        // Render
        try renderer.setDrawColor(Colors.black().toPixels());
        try renderer.clear();

        try renderer.renderTexture(
            texture_text,
            null,
            .{
                .x = 0.0,
                .y = 0.0,
                .w = @floatFromInt(texture_text.getWidth()),
                .h = @floatFromInt(texture_text.getHeight()),
            }
        );

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
