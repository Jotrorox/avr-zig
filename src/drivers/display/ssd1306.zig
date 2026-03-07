const i2c = @import("../../hal/i2c.zig");

pub const default_address: u7 = 0x3C;

pub const Color = enum(u1) {
    off = 0,
    on = 1,
};

pub fn Display(comptime display_width: u8, comptime display_height: u8) type {
    comptime {
        if (display_width == 0 or display_height == 0) {
            @compileError("SSD1306 width and height must be greater than zero");
        }
        if (display_height % 8 != 0) {
            @compileError("SSD1306 height must be divisible by 8");
        }
    }

    const page_count: usize = display_height / 8;
    const buffer_len: usize = @as(usize, display_width) * page_count;
    const multiplex_ratio = display_height - 1;
    const com_pins_config: u8 = if (display_height == 64) 0x12 else 0x02;

    return struct {
        const Self = @This();

        pub const width = display_width;
        pub const height = display_height;
        pub const pages = page_count;
        pub const framebuffer_len = buffer_len;

        address: u7 = default_address,
        buffer: [buffer_len]u8 = [_]u8{0} ** buffer_len,

        pub fn init(self: *Self) bool {
            const commands = [_]u8{
                0xAE,
                0xD5,
                0x80,
                0xA8,
                multiplex_ratio,
                0xD3,
                0x00,
                0x40,
                0x8D,
                0x14,
                0x20,
                0x02,
                0xA1,
                0xC8,
                0xDA,
                com_pins_config,
                0x81,
                0xCF,
                0xD9,
                0xF1,
                0xDB,
                0x40,
                0xA4,
                0xA6,
                0x2E,
                0xAF,
            };

            self.clear(.off);
            if (!self.writeCommands(commands.len, &commands)) {
                return false;
            }

            return self.present();
        }

        pub fn clear(self: *Self, color: Color) void {
            const fill = if (color == .on) @as(u8, 0xFF) else 0x00;
            const buffer_ptr: [*]volatile u8 = @ptrCast(&self.buffer);
            var index: usize = 0;
            while (index < buffer_len) : (index += 1) {
                buffer_ptr[index] = fill;
            }
        }

        pub fn drawPixel(self: *Self, x: u8, y: u8, color: Color) void {
            if (x >= width or y >= height) {
                return;
            }

            const page = @as(usize, y) >> 3;
            const index = page * width + @as(usize, x);
            const mask = @as(u8, 1) << @as(u3, @intCast(y & 0x07));
            const buffer_ptr: [*]u8 = &self.buffer;

            if (color == .on) {
                buffer_ptr[index] |= mask;
            } else {
                buffer_ptr[index] &= ~mask;
            }
        }

        pub fn drawLine(self: *Self, x0: i16, y0: i16, x1: i16, y1: i16, color: Color) void {
            var current_x = x0;
            var current_y = y0;
            const dx = absDiff(x1, x0);
            const dy = absDiff(y1, y0);
            const step_x: i16 = if (x0 < x1) 1 else -1;
            const step_y: i16 = if (y0 < y1) 1 else -1;
            var error_term = dx - dy;

            while (true) {
                drawPixelSigned(self, current_x, current_y, color);
                if (current_x == x1 and current_y == y1) {
                    break;
                }

                const doubled_error = error_term * 2;
                if (doubled_error > -dy) {
                    error_term -= dy;
                    current_x += step_x;
                }
                if (doubled_error < dx) {
                    error_term += dx;
                    current_y += step_y;
                }
            }
        }

        pub fn present(self: *Self) bool {
            const buffer_ptr: [*]const u8 = &self.buffer;
            var page: usize = 0;
            while (page < page_count) : (page += 1) {
                const page_command = @as(u8, 0xB0) + @as(u8, @intCast(page));
                const commands = [_]u8{ page_command, 0x00, 0x10 };
                if (!self.writeCommands(commands.len, &commands)) {
                    return false;
                }

                if (!i2c.startWrite(self.address)) {
                    return false;
                }

                if (!i2c.writeData(0x40)) {
                    i2c.stop();
                    return false;
                }

                var column: usize = 0;
                const page_offset = page * width;
                while (column < width) : (column += 1) {
                    if (!i2c.writeData(buffer_ptr[page_offset + column])) {
                        i2c.stop();
                        return false;
                    }
                }

                i2c.stop();
            }

            return true;
        }

        fn writeCommands(self: *Self, comptime command_count: usize, commands: *const [command_count]u8) bool {
            if (!i2c.startWrite(self.address)) {
                return false;
            }

            if (!i2c.writeData(0x00)) {
                i2c.stop();
                return false;
            }

            inline for (commands.*) |command| {
                if (!i2c.writeData(command)) {
                    i2c.stop();
                    return false;
                }
            }

            i2c.stop();
            return true;
        }

        fn drawPixelSigned(display: *Self, x: i16, y: i16, color: Color) void {
            if (x < 0 or y < 0 or x >= width or y >= height) {
                return;
            }

            display.drawPixel(@as(u8, @intCast(x)), @as(u8, @intCast(y)), color);
        }
    };
}

fn absDiff(a: i16, b: i16) i16 {
    return if (a >= b) a - b else b - a;
}
