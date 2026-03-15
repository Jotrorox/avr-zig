const avr = @import("avr_zig");
const seven_segment = avr.drivers.display.seven_segment;
const uart = avr.uart;

const common = seven_segment.Common.cathode;

const Display = seven_segment.FourDigit(
    .{
        .a = .D2,
        .b = .D3,
        .c = .D4,
        .d = .D5,
        .e = .D6,
        .f = .D7,
        .g = .D8,
        .dp = .D9,
    },
    .{
        .d1 = .D10,
        .d2 = .D11,
        .d3 = .D12,
        .d4 = .D13,
    },
    common,
);

var display: Display = .{};

pub fn main() void {
    uart.init(115200);
    uart.write("4-digit 7-segment example\r\n");
    uart.write("Segments A..G -> D2..D8, DP -> D9, digits 1..4 -> D10..D13\r\n");
    uart.write("Change `common` to `.anode` for common-anode modules\r\n");

    display.init();

    var value: i16 = 0;
    while (true) {
        display.showNumber(value);
        display.setDecimalPoint(1, true);
        display.refreshFor(1000, 2);

        value += 1;
        if (value > 9999) {
            value = 0;
        }
    }
}
