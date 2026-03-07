const avr = @import("avr_zig");
const hd44780_i2c = avr.drivers.display.hd44780_i2c;
const i2c = avr.i2c;
const time = avr.time;
const uart = avr.uart;

const Display16x2 = hd44780_i2c.Display(16, 2);
const printable_start: u8 = 0x20;
const printable_end: u8 = 0x7E;
const chars_per_page: u8 = 16;
const ascii_page_count: u8 = 6;

var display: Display16x2 = .{};

pub fn main() void {
    uart.init(115200);
    i2c.init();

    scanI2cBus();
    if (!initDisplay()) {
        uart.write("LCD init failed at 0x27/0x3F\r\n");
        while (true) {
            time.sleep(1000);
        }
    }

    var page: u8 = 0;
    while (true) {
        renderPage(page);

        if (display.present()) {
            uart.write("LCD page ");
            uart.write_ch('1' + page);
            uart.write("/6\r\n");
        } else {
            uart.write("LCD update failed\r\n");
        }

        page = if (page + 1 < ascii_page_count) page + 1 else 0;
        time.sleep(1500);
    }
}

fn initDisplay() bool {
    display.address = hd44780_i2c.default_address;
    if (display.init()) {
        uart.write("LCD found at 0x27\r\n");
        return true;
    }

    display.address = hd44780_i2c.alternate_address;
    if (display.init()) {
        uart.write("LCD found at 0x3F\r\n");
        return true;
    }

    display.address = hd44780_i2c.default_address;
    return false;
}

fn renderPage(page: u8) void {
    @setRuntimeSafety(false);

    display.writeLine(0, "ASCII page 1/6");
    display.put(11, 0, '1' + page);

    var row = [_]u8{' '} ** chars_per_page;
    var index: usize = 0;
    while (index < row.len) : (index += 1) {
        const codepoint = printable_start + page * chars_per_page + @as(u8, @intCast(index));
        row[index] = if (codepoint <= printable_end) codepoint else ' ';
    }

    display.writeLine(1, row[0..]);
}

fn scanI2cBus() void {
    uart.write("I2C scan:\r\n");
    const count = i2c.scan(reportDevice);
    if (count == 0) {
        uart.write("  no devices found\r\n");
    }
}

fn reportDevice(address: u7) void {
    uart.write("  found device at 0x");
    writeHexByte(@as(u8, address));
    uart.write("\r\n");
}

fn writeHexByte(value: u8) void {
    writeHexNibble(value >> 4);
    writeHexNibble(value & 0x0F);
}

fn writeHexNibble(value: u8) void {
    const digit = if (value < 10) '0' + value else 'A' + (value - 10);
    uart.write_ch(digit);
}
