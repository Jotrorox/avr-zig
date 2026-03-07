const i2c = @import("../../hal/i2c.zig");
const mono5x7_data = @import("fonts/mono5x7.zig");

pub const default_address: u7 = 0x3C;

pub const Color = enum(u1) {
    off = 0,
    on = 1,
};

pub const Font = struct {
    glyph_width: u8,
    glyph_height: u8,
    first_char: u8,
    glyph_count: u8,
    spacing_x: u8 = 1,
    spacing_y: u8 = 1,
    fallback_char: u8 = '?',
    data: []const u8,

    pub fn bytesPerColumn(self: Font) usize {
        return @as(usize, @intCast((@as(u16, self.glyph_height) + 7) / 8));
    }

    pub fn glyphStride(self: Font) usize {
        return @as(usize, self.glyph_width) * self.bytesPerColumn();
    }

    pub fn lineAdvance(self: Font) u8 {
        return @as(u8, @intCast(@as(u16, self.glyph_height) + self.spacing_y));
    }

    pub fn measureText(self: Font, text: []const u8) u16 {
        @setRuntimeSafety(false);

        var max_width: u16 = 0;
        var line_width: u16 = 0;
        var index: usize = 0;

        while (index < text.len) : (index += 1) {
            const character = text[index];
            if (character == '\r') {
                continue;
            }

            if (character == '\n') {
                if (line_width > max_width) {
                    max_width = line_width;
                }
                line_width = 0;
                continue;
            }

            if (line_width != 0) {
                line_width += self.spacing_x;
            }
            line_width += self.glyph_width;
        }

        if (line_width > max_width) {
            max_width = line_width;
        }

        return max_width;
    }

    pub fn glyph(self: Font, character: u8) [*]const u8 {
        const normalized = self.normalizeChar(character);
        const stride = self.glyphStride();
        const offset = @as(usize, normalized - self.first_char) * stride;
        return self.data.ptr + offset;
    }

    fn normalizeChar(self: Font, character: u8) u8 {
        var normalized = character;
        if (normalized >= 'a' and normalized <= 'z') {
            normalized -= 'a' - 'A';
        }

        if (normalized >= self.first_char and normalized < self.first_char + self.glyph_count) {
            return normalized;
        }

        if (self.fallback_char >= self.first_char and self.fallback_char < self.first_char + self.glyph_count) {
            return self.fallback_char;
        }

        return self.first_char;
    }
};

pub const fonts = struct {
    pub const mono5x7 = Font{
        .glyph_width = mono5x7_data.width,
        .glyph_height = mono5x7_data.height,
        .first_char = mono5x7_data.first_char,
        .glyph_count = mono5x7_data.glyph_count,
        .spacing_x = mono5x7_data.spacing_x,
        .spacing_y = mono5x7_data.spacing_y,
        .fallback_char = mono5x7_data.fallback_char,
        .data = mono5x7_data.data[0..],
    };
};

pub const default_font = fonts.mono5x7;

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

        pub fn drawHorizontalLine(self: *Self, x: i16, y: i16, line_width: u8, color: Color) void {
            var column: u8 = 0;
            while (column < line_width) : (column += 1) {
                drawPixelSigned(self, x + @as(i16, column), y, color);
            }
        }

        pub fn drawVerticalLine(self: *Self, x: i16, y: i16, line_height: u8, color: Color) void {
            var row: u8 = 0;
            while (row < line_height) : (row += 1) {
                drawPixelSigned(self, x, y + @as(i16, row), color);
            }
        }

        pub fn drawRect(self: *Self, x: i16, y: i16, rect_width: u8, rect_height: u8, color: Color) void {
            if (rect_width == 0 or rect_height == 0) {
                return;
            }

            self.drawHorizontalLine(x, y, rect_width, color);
            if (rect_height > 1) {
                self.drawHorizontalLine(x, y + @as(i16, rect_height - 1), rect_width, color);
            }

            if (rect_height > 2) {
                self.drawVerticalLine(x, y + 1, rect_height - 2, color);
                if (rect_width > 1) {
                    self.drawVerticalLine(x + @as(i16, rect_width - 1), y + 1, rect_height - 2, color);
                }
            }
        }

        pub fn fillRect(self: *Self, x: i16, y: i16, rect_width: u8, rect_height: u8, color: Color) void {
            var row: u8 = 0;
            while (row < rect_height) : (row += 1) {
                self.drawHorizontalLine(x, y + @as(i16, row), rect_width, color);
            }
        }

        pub fn drawChar(self: *Self, x: i16, y: i16, character: u8, color: Color, font: Font) void {
            @setRuntimeSafety(false);

            const glyph = font.glyph(character);
            const bytes_per_column = font.bytesPerColumn();

            var column: u8 = 0;
            while (column < font.glyph_width) : (column += 1) {
                const column_offset = @as(usize, column) * bytes_per_column;
                var byte_index: usize = 0;
                while (byte_index < bytes_per_column) : (byte_index += 1) {
                    const packed_bits = glyph[column_offset + byte_index];
                    if (packed_bits == 0) {
                        continue;
                    }

                    var bit_index: u8 = 0;
                    while (bit_index < 8) : (bit_index += 1) {
                        const row = byte_index * 8 + bit_index;
                        if (row >= font.glyph_height) {
                            break;
                        }

                        const mask = @as(u8, 1) << @as(u3, @intCast(bit_index));
                        if ((packed_bits & mask) != 0) {
                            drawPixelSigned(
                                self,
                                x + @as(i16, column),
                                y + @as(i16, @intCast(row)),
                                color,
                            );
                        }
                    }
                }
            }
        }

        pub fn drawText(self: *Self, x: i16, y: i16, text: []const u8, color: Color, font: Font) void {
            @setRuntimeSafety(false);

            var cursor_x = x;
            var cursor_y = y;
            const advance_x = @as(i16, font.glyph_width) + @as(i16, font.spacing_x);
            const advance_y = @as(i16, font.glyph_height) + @as(i16, font.spacing_y);
            var index: usize = 0;

            while (index < text.len) : (index += 1) {
                const character = text[index];
                if (character == '\r') {
                    continue;
                }

                if (character == '\n') {
                    cursor_x = x;
                    cursor_y += advance_y;
                    continue;
                }

                self.drawChar(cursor_x, cursor_y, character, color, font);
                cursor_x += advance_x;
            }
        }

        pub fn measureText(_: *Self, text: []const u8, font: Font) u16 {
            return font.measureText(text);
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
