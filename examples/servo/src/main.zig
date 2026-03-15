const builtin = @import("builtin");
const std = @import("std");
const avr = @import("avr_zig");
const servo = avr.drivers.actuator.servo;
const time = avr.time;

const positions = [_]u8{ 0, 90, 180, 90 };
const servo_pin: avr.gpio.Pin = if (std.mem.eql(u8, builtin.target.cpu.model.name, "atmega2560")) .D11 else .D9;

pub fn main() void {
    servo.init(servo_pin);

    while (true) {
        inline for (positions) |position| {
            servo.writeDegrees(servo_pin, position);
            time.sleep(900);
        }
    }
}
