const avr = @import("avr_zig");
const dht11 = avr.drivers.sensor.dht11;
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);
    uart.write("DHT11 example on D4\r\n");

    while (true) {
        const reading = dht11.read(.D4) catch |err| {
            uart.write("read failed: ");
            uart.write(@errorName(err));
            uart.write("\r\n");
            time.sleep(2000);
            continue;
        };

        uart.write("humidity=");
        uart.write(reading.humidity);
        uart.write(".");
        writeTwoDigits(reading.humidity_decimal);
        uart.write("% temperature=");
        uart.write(reading.temperature);
        uart.write(".");
        writeTwoDigits(reading.temperature_decimal);
        uart.write("C\r\n");
        time.sleep(2000);
    }
}

fn writeTwoDigits(value: u8) void {
    var tens: u8 = 0;
    var ones = value;

    while (ones >= 10) : (tens += 1) {
        ones -= 10;
    }

    uart.write_ch('0' + tens);
    uart.write_ch('0' + ones);
}
