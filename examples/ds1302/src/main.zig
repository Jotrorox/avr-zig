const avr = @import("avr_zig");

const time = avr.time;
const uart = avr.uart;
const ds1302 = avr.drivers.sensor.ds1302;

const Rtc = ds1302.Device(.D8, .A4, .A5);

const startup_time = ds1302.DateTime{
    .second = 0,
    .minute = 0,
    .hour = 12,
    .day = 7,
    .month = 3,
    .weekday = 7,
    .year = 2026,
};

pub fn main() void {
    uart.init(115200);

    var rtc = Rtc{};
    rtc.init();

    uart.write("Setting DS1302 clock on D8/A4/A5...\r\n");
    rtc.writeDateTime(startup_time) catch {
        uart.write("Failed to write startup time\r\n");
        while (true) {
            time.sleep(1000);
        }
    };

    uart.write("Clock set. Streaming current time:\r\n");

    while (true) {
        const now = rtc.readDateTime();
        writeDateTime(now);
        time.sleep(1000);
    }
}

fn writeDateTime(date_time: ds1302.DateTime) void {
    writeDec4(date_time.year);
    uart.write("-");
    writeDec2(date_time.month);
    uart.write("-");
    writeDec2(date_time.day);
    uart.write(" ");
    writeDec2(date_time.hour);
    uart.write(":");
    writeDec2(date_time.minute);
    uart.write(":");
    writeDec2(date_time.second);
    uart.write("  weekday=");
    writeDec1(date_time.weekday);
    uart.write("\r\n");
}

fn writeDec1(value: u8) void {
    uart.write_ch('0' + value);
}

fn writeDec2(value: u8) void {
    var remaining = value;
    const tens = countDigitU8(&remaining, 10);

    uart.write_ch('0' + tens);
    uart.write_ch('0' + remaining);
}

fn writeDec4(value: u16) void {
    var remaining = value;
    const thousands = countDigitU16(&remaining, 1000);
    const hundreds = countDigitU16(&remaining, 100);
    const tens = countDigitU16(&remaining, 10);

    uart.write_ch('0' + thousands);
    uart.write_ch('0' + hundreds);
    uart.write_ch('0' + tens);
    uart.write_ch('0' + @as(u8, @intCast(remaining)));
}

fn countDigitU8(remaining: *u8, place: u8) u8 {
    var digit: u8 = 0;
    while (remaining.* >= place) : (remaining.* -= place) {
        digit += 1;
    }
    return digit;
}

fn countDigitU16(remaining: *u16, place: u16) u8 {
    var digit: u8 = 0;
    while (remaining.* >= place) : (remaining.* -= place) {
        digit += 1;
    }
    return digit;
}
