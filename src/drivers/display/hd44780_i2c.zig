const i2c = @import("../../hal/i2c.zig");
const time = @import("../../hal/time.zig");

pub const default_address: u7 = 0x27;
pub const alternate_address: u7 = 0x3F;

const bit_rs: u8 = 1 << 0;
const bit_rw: u8 = 1 << 1;
const bit_enable: u8 = 1 << 2;
const bit_backlight: u8 = 1 << 3;

const cmd_clear_display: u8 = 0x01;
const cmd_return_home: u8 = 0x02;
const cmd_entry_mode_set: u8 = 0x04;
const cmd_display_control: u8 = 0x08;
const cmd_function_set: u8 = 0x20;
const cmd_set_ddram_addr: u8 = 0x80;

const flag_entry_left: u8 = 0x02;
const flag_display_on: u8 = 0x04;
const flag_function_2line: u8 = 0x08;
const flag_function_5x10dots: u8 = 0x04;

pub fn Display(comptime display_columns: u8, comptime display_rows: u8) type {
    comptime {
        if (display_columns == 0 or display_rows == 0) {
            @compileError("HD44780 dimensions must be greater than zero");
        }

        if (display_rows > 4) {
            @compileError("HD44780 driver supports up to 4 rows");
        }
    }

    const buffer_len: usize = @as(usize, display_columns) * @as(usize, display_rows);

    return struct {
        const Self = @This();

        pub const width = display_columns;
        pub const height = display_rows;
        pub const text_buffer_len = buffer_len;

        address: u7 = default_address,
        backlight_enabled: bool = true,
        buffer: [buffer_len]u8 = [_]u8{' '} ** buffer_len,

        pub fn init(self: *Self) bool {
            fillBuffer(self, ' ');
            time.sleep(50);

            if (!self.writeInitializationNibble(0x03, 5)) {
                return false;
            }
            if (!self.writeInitializationNibble(0x03, 5)) {
                return false;
            }
            if (!self.writeInitializationNibble(0x03, 2)) {
                return false;
            }
            if (!self.writeInitializationNibble(0x02, 2)) {
                return false;
            }

            var function_flags = flag_function_5x10dots;
            if (display_rows > 1) {
                function_flags = flag_function_2line;
            }

            if (!self.writeCommand(cmd_function_set | function_flags, 1)) {
                return false;
            }
            if (!self.writeCommand(cmd_display_control, 1)) {
                return false;
            }
            if (!self.writeCommand(cmd_entry_mode_set | flag_entry_left, 1)) {
                return false;
            }
            if (!self.writeCommand(cmd_display_control | flag_display_on, 1)) {
                return false;
            }
            if (!self.writeCommand(cmd_clear_display, 2)) {
                return false;
            }

            return self.present();
        }

        pub fn clear(self: *Self) bool {
            fillBuffer(self, ' ');
            if (!self.writeCommand(cmd_clear_display, 2)) {
                return false;
            }
            return self.present();
        }

        pub fn home(self: *Self) bool {
            return self.writeCommand(cmd_return_home, 2);
        }

        pub fn setBacklight(self: *Self, enabled: bool) bool {
            self.backlight_enabled = enabled;

            if (!i2c.startWrite(self.address)) {
                return false;
            }

            if (!i2c.writeData(self.backlightMask())) {
                i2c.stop();
                return false;
            }

            i2c.stop();
            time.sleep(1);
            return true;
        }

        pub fn put(self: *Self, column: u8, row: u8, char: u8) void {
            if (column >= width or row >= height) {
                return;
            }

            const index = bufferIndex(column, row);
            const buffer_ptr: [*]u8 = &self.buffer;
            buffer_ptr[index] = normalizeChar(char);
        }

        pub fn writeLine(self: *Self, row: u8, text: []const u8) void {
            @setRuntimeSafety(false);

            if (row >= height) {
                return;
            }

            const row_width = @as(usize, width);
            const row_start = @as(usize, row) * row_width;
            const row_slice = self.buffer[row_start .. row_start + row_width];

            var column: usize = 0;
            while (column < row_slice.len) : (column += 1) {
                row_slice[column] = ' ';
            }

            var text_index: usize = 0;
            column = 0;
            while (text_index < text.len and column < row_slice.len) : (text_index += 1) {
                const char = text[text_index];
                if (char == '\n') {
                    break;
                }

                row_slice[column] = normalizeChar(char);
                column += 1;
            }
        }

        pub fn write(self: *Self, start_column: u8, start_row: u8, text: []const u8) void {
            if (start_row >= height or start_column >= width) {
                return;
            }

            var column = start_column;
            var row = start_row;
            var text_index: usize = 0;

            while (text_index < text.len and row < height) : (text_index += 1) {
                const char = text[text_index];
                if (char == '\n') {
                    row += 1;
                    column = 0;
                    continue;
                }

                if (column >= width) {
                    row += 1;
                    column = 0;
                    if (row >= height) {
                        break;
                    }
                }

                self.put(column, row, char);
                column += 1;
            }
        }

        pub fn present(self: *Self) bool {
            const buffer_ptr: [*]const u8 = &self.buffer;
            var row: u8 = 0;
            while (row < height) : (row += 1) {
                if (!self.writeCommand(cmd_set_ddram_addr | ddramBase(row), 1)) {
                    return false;
                }

                if (!i2c.startWrite(self.address)) {
                    return false;
                }

                var column: u8 = 0;
                while (column < width) : (column += 1) {
                    const index = @as(usize, row) * width + @as(usize, column);
                    if (!self.writeByteInTransaction(buffer_ptr[index], true)) {
                        i2c.stop();
                        return false;
                    }
                }

                i2c.stop();
            }

            return true;
        }

        pub fn setCursor(self: *Self, column: u8, row: u8) bool {
            if (column >= width or row >= height) {
                return false;
            }

            return self.writeCommand(cmd_set_ddram_addr | (ddramBase(row) + column), 1);
        }

        pub fn writeChar(self: *Self, char: u8) bool {
            const sanitized = normalizeChar(char);

            if (!i2c.startWrite(self.address)) {
                return false;
            }

            if (!self.writeByteInTransaction(sanitized, true)) {
                i2c.stop();
                return false;
            }

            i2c.stop();
            return true;
        }

        fn writeInitializationNibble(self: *Self, nibble: u8, delay_ms: u32) bool {
            if (!i2c.startWrite(self.address)) {
                return false;
            }

            if (!self.write4BitsInTransaction(nibble, false)) {
                i2c.stop();
                return false;
            }

            i2c.stop();
            time.sleep(delay_ms);
            return true;
        }

        fn writeCommand(self: *Self, command: u8, delay_ms: u32) bool {
            if (!i2c.startWrite(self.address)) {
                return false;
            }

            if (!self.writeByteInTransaction(command, false)) {
                i2c.stop();
                return false;
            }

            i2c.stop();
            if (delay_ms != 0) {
                time.sleep(delay_ms);
            }
            return true;
        }

        fn writeByteInTransaction(self: *Self, byte: u8, register_select: bool) bool {
            if (!self.write4BitsInTransaction(byte >> 4, register_select)) {
                return false;
            }

            return self.write4BitsInTransaction(byte & 0x0F, register_select);
        }

        fn write4BitsInTransaction(self: *Self, nibble: u8, register_select: bool) bool {
            const control_bits = (if (register_select) bit_rs else @as(u8, 0)) | self.backlightMask();
            const bus_value = ((nibble & 0x0F) << 4) | control_bits;

            if (!i2c.writeData(bus_value & ~bit_enable & ~bit_rw)) {
                return false;
            }
            if (!i2c.writeData(bus_value | bit_enable)) {
                return false;
            }
            if (!i2c.writeData(bus_value & ~bit_enable)) {
                return false;
            }

            return true;
        }

        fn backlightMask(self: *Self) u8 {
            return if (self.backlight_enabled) bit_backlight else 0;
        }

        fn fillBuffer(self: *Self, char: u8) void {
            const sanitized = normalizeChar(char);
            const buffer_ptr: [*]volatile u8 = @ptrCast(&self.buffer);
            var index: usize = 0;
            while (index < buffer_len) : (index += 1) {
                buffer_ptr[index] = sanitized;
            }
        }

        fn bufferIndex(column: u8, row: u8) usize {
            return @as(usize, row) * width + @as(usize, column);
        }
    };
}

fn normalizeChar(char: u8) u8 {
    return if (char >= 0x20 and char <= 0x7E) char else '?';
}

fn ddramBase(row: u8) u8 {
    return switch (row) {
        0 => 0x00,
        1 => 0x40,
        2 => 0x14,
        3 => 0x54,
        else => 0x00,
    };
}
