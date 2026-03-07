const gpio = @import("../../hal/gpio.zig");
const uno = @import("../../board/uno.zig");

const delay_cycles = @max(uno.CPU_FREQ / 8_000_000, 1);

const register_seconds = 0x80;
const register_minutes = 0x82;
const register_hours = 0x84;
const register_date = 0x86;
const register_month = 0x88;
const register_day = 0x8A;
const register_year = 0x8C;
const register_write_protect = 0x8E;
const register_clock_burst = 0xBE;

pub const Error = error{
    InvalidDateTime,
};

pub const DateTime = struct {
    second: u8,
    minute: u8,
    hour: u8,
    day: u8,
    month: u8,
    weekday: u8,
    year: u16,
};

pub fn Device(
    comptime rst_pin: gpio.Pin,
    comptime io_pin: gpio.Pin,
    comptime clk_pin: gpio.Pin,
) type {
    comptime ensureDistinctPins(rst_pin, io_pin, clk_pin);

    return struct {
        const Self = @This();

        pub fn init(self: *Self) void {
            _ = self;

            gpio.init(rst_pin, .out);
            gpio.init(clk_pin, .out);
            gpio.init(io_pin, .out);

            gpio.write(rst_pin, false);
            gpio.write(clk_pin, false);
            gpio.write(io_pin, false);
        }

        pub fn readDateTime(self: *Self) DateTime {
            self.init();

            var burst: [8]u8 = undefined;
            readBurst(&burst);

            return .{
                .second = decodeBcd(burst[0] & 0x7F),
                .minute = decodeBcd(burst[1] & 0x7F),
                .hour = decodeHour(burst[2]),
                .day = decodeBcd(burst[3] & 0x3F),
                .month = decodeBcd(burst[4] & 0x1F),
                .weekday = decodeBcd(burst[5] & 0x07),
                .year = @as(u16, 2000) + @as(u16, decodeBcd(burst[6])),
            };
        }

        pub fn writeDateTime(self: *Self, date_time: DateTime) Error!void {
            self.init();
            try validate(date_time);

            try self.setWriteProtect(false);

            const burst = [8]u8{
                encodeBcd(date_time.second),
                encodeBcd(date_time.minute),
                encodeBcd(date_time.hour),
                encodeBcd(date_time.day),
                encodeBcd(date_time.month),
                encodeBcd(date_time.weekday),
                encodeBcd(@as(u8, @intCast(date_time.year - 2000))),
                0,
            };

            writeBurst(burst);
            try self.setWriteProtect(true);
        }

        pub fn setWriteProtect(self: *Self, enabled: bool) Error!void {
            _ = self;
            try writeRegister(register_write_protect, if (enabled) 0x80 else 0x00);
        }

        fn readBurst(buffer: *[8]u8) void {
            beginWrite();
            writeByte(register_clock_burst | 0x01);
            gpio.init(io_pin, .in);
            gpio.setPullup(io_pin, false);

            for (buffer, 0..) |*byte, index| {
                _ = index;
                byte.* = readByte();
            }

            endTransaction();
        }

        fn writeBurst(buffer: [8]u8) void {
            beginWrite();
            writeByte(register_clock_burst);
            for (buffer) |byte| {
                writeByte(byte);
            }
            endTransaction();
        }

        fn writeRegister(command: u8, value: u8) Error!void {
            if ((command & 0x01) != 0) {
                return error.InvalidDateTime;
            }

            beginWrite();
            writeByte(command);
            writeByte(value);
            endTransaction();
        }

        fn beginWrite() void {
            gpio.init(io_pin, .out);
            gpio.write(clk_pin, false);
            gpio.write(rst_pin, true);
            shortDelay();
        }

        fn endTransaction() void {
            gpio.write(rst_pin, false);
            gpio.write(clk_pin, false);
            gpio.init(io_pin, .out);
            gpio.write(io_pin, false);
            shortDelay();
        }

        fn writeByte(value: u8) void {
            var shifted = value;
            inline for (0..8) |_| {
                gpio.write(io_pin, (shifted & 0x01) != 0);
                shortDelay();
                gpio.write(clk_pin, true);
                shortDelay();
                gpio.write(clk_pin, false);
                shortDelay();
                shifted >>= 1;
            }
        }

        fn readByte() u8 {
            var value: u8 = 0;

            inline for (0..8) |bit_index| {
                shortDelay();
                gpio.write(clk_pin, true);
                shortDelay();
                if (gpio.read(io_pin)) {
                    value |= @as(u8, 1) << @as(u3, @intCast(bit_index));
                }
                gpio.write(clk_pin, false);
                shortDelay();
            }

            return value;
        }
    };
}

fn ensureDistinctPins(
    comptime rst_pin: gpio.Pin,
    comptime io_pin: gpio.Pin,
    comptime clk_pin: gpio.Pin,
) void {
    if (rst_pin == io_pin or rst_pin == clk_pin or io_pin == clk_pin) {
        @compileError("DS1302 RST, IO, and CLK pins must be different");
    }
}

fn validate(date_time: DateTime) Error!void {
    if (date_time.second > 59 or
        date_time.minute > 59 or
        date_time.hour > 23 or
        date_time.day < 1 or
        date_time.day > daysInMonth(date_time.year, date_time.month) or
        date_time.month < 1 or
        date_time.month > 12 or
        date_time.weekday < 1 or
        date_time.weekday > 7 or
        date_time.year < 2000 or
        date_time.year > 2099)
    {
        return error.InvalidDateTime;
    }
}

fn daysInMonth(year: u16, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

fn isLeapYear(year: u16) bool {
    if ((year % 400) == 0) return true;
    if ((year % 100) == 0) return false;
    return (year % 4) == 0;
}

fn encodeBcd(value: u8) u8 {
    return ((value / 10) << 4) | (value % 10);
}

fn decodeBcd(value: u8) u8 {
    return ((value >> 4) * 10) + (value & 0x0F);
}

fn decodeHour(raw: u8) u8 {
    if ((raw & 0x80) == 0) {
        return decodeBcd(raw & 0x3F);
    }

    const hour = decodeBcd(raw & 0x1F);
    const is_pm = (raw & 0x20) != 0;

    if (hour == 12) {
        return if (is_pm) 12 else 0;
    }

    return if (is_pm) hour + 12 else hour;
}

fn shortDelay() void {
    inline for (0..delay_cycles) |_| {
        asm volatile ("nop");
    }
}
