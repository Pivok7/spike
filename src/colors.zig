const sdl3 = @import("sdl3");

pub const Colors = struct{
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    const Self = @This();

    pub fn white() Self {
        return .{ .r = 255, .g = 255, .b = 255, .a = 255};
    }

    pub fn black() Self {
        return .{ .r = 0, .g = 0, .b = 0, .a = 255};
    }

    pub fn toSDL3Type(self: Self, T: type) T {
        return .{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }

    pub fn toPixels(self: *const @This()) sdl3.pixels.Color {
        return self.toSDL3Type(sdl3.pixels.Color);
    }

    pub fn toTTF(self: *const @This()) sdl3.ttf.Color {
        return self.toSDL3Type(sdl3.ttf.Color);
    }
};

