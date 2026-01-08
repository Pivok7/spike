const std = @import("std");

pub const utf8Iterator = struct {
    string: []const u8,
    pos: usize,

    const Self = @This();

    pub fn init(string: []const u8) Self {
        return .{
            .string = string,
            .pos = 0,
        };
    }

    pub fn nextCodepoint(self: *Self) ?u21 {
        if (self.pos >= self.string.len) return null;

        while (true) {
            const utf8_len = std.unicode.utf8ByteSequenceLength(
                self.string[self.pos]
            ) catch {
                self.pos += 1;
                if (self.pos >= self.string.len) return null;
                continue;
            };

            if (self.pos + utf8_len > self.string.len) return null;

            const codepoint = std.unicode.utf8Decode(
                self.string[self.pos..(self.pos + utf8_len)]
            ) catch {
                self.pos += 1;
                if (self.pos >= self.string.len) return null;
                continue;
            };

            self.pos += utf8_len;
            return codepoint;
        }
    }
};

