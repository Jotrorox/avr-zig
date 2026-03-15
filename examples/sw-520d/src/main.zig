const avr = @import("avr_zig");
const gpio = avr.gpio;
const sw_520d = avr.drivers.sensor.sw_520d;
const time = avr.time;
const uart = avr.uart;

const tilt_pin: avr.gpio.Pin = .D2;
const led_pin: avr.gpio.Pin = .D13;

pub fn main() void {
    uart.init(115200);
    sw_520d.init(tilt_pin, true);
    gpio.init(led_pin, .out);

    // This example assumes the switch closes to GND when tilted.
    var tilted = sw_520d.isClosed(tilt_pin);
    gpio.write(led_pin, tilted);
    reportState(tilted);

    while (true) {
        const sample = sw_520d.isClosed(tilt_pin);
        if (sample != tilted) {
            time.sleep(20);
            const confirmed = sw_520d.isClosed(tilt_pin);
            if (confirmed != tilted) {
                tilted = confirmed;
                gpio.write(led_pin, tilted);
                reportState(tilted);
            }
        }
        time.sleep(10);
    }
}

fn reportState(tilted: bool) void {
    uart.write("tilt=");
    uart.write(if (tilted) "tilted" else "level");
    uart.write("\r\n");
}
