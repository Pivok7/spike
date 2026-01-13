const std = @import("std");
const sdl3 = @import("sdl3");
const Colors = @import("colors.zig").Colors;

const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
map: std.AutoHashMap(u32, sdl3.render.Texture),
font: sdl3.ttf.Font,
renderer: sdl3.render.Renderer,

pub fn init(
    allocator: Allocator,
    font: sdl3.ttf.Font,
    renderer: sdl3.render.Renderer,
) Self {
    return .{
        .allocator = allocator,
        .map = .init(allocator),
        .font = font,
        .renderer = renderer,
    };
}

pub fn getTexture(self: *Self, codepoint: u32) !?sdl3.render.Texture {
    if (self.map.get(codepoint)) |texture| return texture;

    if (self.font.hasGlyph(codepoint)) {
        var utf8_buf: [4]u8 = undefined;
        const utf8_len = try std.unicode.utf8Encode(
            @intCast(codepoint),
            &utf8_buf,
        );
        const utf8_c = utf8_buf[0..utf8_len];

        const glyph_surface = self.font.renderTextBlended(
            utf8_c,
            Colors.white().toTTF()
        ) catch {
            std.log.err("Failed to load glyph {d}", .{codepoint});
            return null;
        };
        const glyph_texture = try self.renderer.createTextureFromSurface(
            glyph_surface
        );
        glyph_surface.deinit();

        try self.map.putNoClobber(codepoint, glyph_texture);

        //std.debug.print("Loaded glyph {s}\n", .{utf8_c});

        return glyph_texture;
    }

    return null;
}

pub fn deinit(self: *Self) void {
    var map_iter = self.map.valueIterator();
    while (map_iter.next()) |texture| {
        texture.deinit();
    }

    self.map.deinit();
}
