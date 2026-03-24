const avr = @import("avr_zig");
const hc_sr04 = avr.drivers.sensor.hc_sr04;
const time = avr.time;
const uart = avr.uart;

const echo_pin: avr.gpio.Pin = .D6;
const trig_pin: avr.gpio.Pin = .D7;

pub fn main() void {
    uart.init(115200);
    hc_sr04.init(echo_pin, trig_pin);
    uart.write("HC-SR04 example echo=D6 trig=D7\r\n");

    while (true) {
        const reading = hc_sr04.read(echo_pin, trig_pin) catch |err| {
            uart.write("read failed: ");
            uart.write(@errorName(err));
            uart.write("\r\n");
            time.sleep(250);
            continue;
        };

        uart.write("distance=");
        uart.write(reading.distance_cm);
        uart.write("cm\r\n");
        time.sleep(250);
    }
}
