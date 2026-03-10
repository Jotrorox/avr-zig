const avr = @import("avr_zig");
const hd44780_i2c = avr.drivers.display.hd44780_i2c;
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
    
    display.address = hd44780_i2c.default_address;
    // If you have one with the 0x3F address just use .alternate_address
    if (!display.init()) {
        uart.write("LCD Not found!\n");
        while (true) { time.sleep(500); }
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
