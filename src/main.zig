const sdl3 = @import("sdl3");
const std = @import("std");

const fps = 60;
const screen_width = 640;
const screen_height = 480;

pub fn main() !void {
    defer sdl3.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = sdl3.InitFlags{};
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

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

    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = sdl3.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    var quit = false;
    while (!quit) {

        // Delay to limit the FPS, returned delta time not needed.
        const dt = fps_capper.delay();
        _ = dt;

        // Update logic.
        const surface = try window.getSurface();
        try surface.fillRect(null, surface.mapRgb(128, 30, 255));
        try surface.fillRect(
            .{ .x = 0, .y = 0, .w = 100, .h = 100 },
            surface.mapRgb(0, 200, 100),
        );
        for (0..100) |i| {
            try surface.writePixel(10, i, .{ .r = 10, .g = 20, .b = 10, .a = 100 });
            try surface.writePixel(11, i, .{ .r = 10, .g = 20, .b = 10, .a = 100 });
        }
        try window.updateSurface();

        // Event logic.
        while (sdl3.events.poll()) |event|
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                else => {},
            };
    }
}
