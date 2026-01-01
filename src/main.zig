const sdl3 = @import("sdl3");
const std = @import("std");
const colors = @import("colors.zig");

const default_font = @embedFile("fonts/Hack-Regular.ttf");
const default_font_size = 16.0;

const Colors = colors.Colors;

const screen_width = 800;
const screen_height = 600;

pub fn main() !void {
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

    const cwd = std.fs.cwd();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const pwd = try cwd.realpath(".", &buf);
    // Null terminate
    buf[@min(pwd.len, std.fs.max_path_bytes - 1)] = 0;

    const text = try font.renderTextBlended(pwd, Colors.white().toTTF());

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
