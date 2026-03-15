const avr = @import("avr_zig");
const seven_segment = avr.drivers.display.seven_segment;
const time = avr.time;
const uart = avr.uart;

const common = seven_segment.Common.anode;

const Display = seven_segment.SingleDigit(.{
    .a = .D2,
    .b = .D3,
    .c = .D4,
    .d = .D5,
    .e = .D6,
    .f = .D7,
    .g = .D8,
    .dp = .D9,
}, common);

var display: Display = .{};

pub fn main() void {
    uart.init(115200);
    uart.write("Single 7-segment example\r\n");
    uart.write("Pins: A..G -> D2..D8, DP -> D9\r\n");
    uart.write("Change `common` to `.cathode` for common-cathode modules\r\n");

    display.init();

    while (true) {
        var digit: u8 = 0;
        while (digit < 10) : (digit += 1) {
            display.showDigit(@as(u4, @intCast(digit)));
            display.setDecimalPoint(digit & 1 == 0);
            time.sleep(700);
        }
    }
}
