const sdl3 = @import("sdl3");
const std = @import("std");

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

    var quit = false;
    while (!quit) {
        // Render
        try renderer.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 255 });
        try renderer.clear();

        try renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 255, .a = 255 });
        const cwd = std.fs.cwd();
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const pwd = try cwd.realpath(".", &buf);
        buf[@min(pwd.len, std.fs.max_path_bytes - 1)] = 0; // Null terminate
        try renderer.renderDebugText(.{ .x = 0.0, .y = 0.0 }, @ptrCast(pwd));

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
