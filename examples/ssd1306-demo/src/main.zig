const avr = @import("avr_zig");
const time = avr.hal.time;
const uart = avr.hal.uart;
const ssd1306 = avr.drivers.display.ssd1306;

const Display128x64 = ssd1306.Display(128, 64);

var display: Display128x64 = .{};

pub fn main() void {
    uart.init(115200);

    initDisplay();

    while (true) {
        time.sleep(500);
    }
}

fn initDisplay() void {
    if (!display.init()) {
        uart.write("SSD1306 init failed\r\n");
        return;
    }

    display.clear(.off);
    display.drawRect(0, 0, 128, 64, .on);
    display.fillRect(4, 4, 120, 12, .on);
    display.drawText(12, 6, "AVR ZIG", .off, ssd1306.default_font);

    display.drawRect(6, 22, 116, 16, .on);
    display.drawText(12, 27, "SSD1306 DEMO", .on, ssd1306.default_font);

    display.drawLine(8, 48, 56, 48, .on);
    display.drawLine(8, 52, 56, 52, .on);
    display.drawLine(8, 56, 56, 56, .on);

    display.fillRect(78, 44, 40, 14, .on);
    display.drawText(88, 48, "OK", .off, ssd1306.default_font);

    if (display.present()) {
        uart.write("SSD1306 demo drawn\r\n");
    } else {
        uart.write("SSD1306 update failed\r\n");
    }
}
