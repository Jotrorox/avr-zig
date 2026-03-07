const avr = @import("avr_zig");
const pwm = avr.pwm;
const time = avr.time;

const red_pin: avr.gpio.Pin = .D9;
const green_pin: avr.gpio.Pin = .D10;
const blue_pin: avr.gpio.Pin = .D11;

pub fn main() void {
    pwm.init(red_pin);
    pwm.init(green_pin);
    pwm.init(blue_pin);

    while (true) {
        crossFade(red_pin, green_pin);
        crossFade(green_pin, blue_pin);
        crossFade(blue_pin, red_pin);
    }
}

fn crossFade(comptime from_pin: avr.gpio.Pin, comptime to_pin: avr.gpio.Pin) void {
    var duty: u16 = 0;
    while (duty <= pwm.max_duty) : (duty += 1) {
        const amount = @as(u8, @intCast(duty));
        pwm.write(from_pin, pwm.max_duty - amount);
        pwm.write(to_pin, amount);
        time.sleep(8);
    }
}
