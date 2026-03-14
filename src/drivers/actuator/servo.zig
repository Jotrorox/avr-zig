const gpio = @import("../../hal/gpio.zig");
const platform = @import("../../platform/current.zig");
const regs = platform.registers;

pub const refresh_hz: u16 = 50;
pub const min_pulse_us: u16 = 1000;
pub const center_pulse_us: u16 = 1500;
pub const max_pulse_us: u16 = 2000;

const timer1_clock_select = 0b010;
const timer1_top: u16 = 40_000;
const ticks_per_us: u16 = 2;
const fast_pwm_icr1_wgm_low = 0b10;
const fast_pwm_icr1_wgm_high = 0b11;
const non_inverting_compare_output = 0b10;

var active = false;

/// Returns whether servo output is supported.
pub fn supports(comptime pin: gpio.Pin) bool {
    return platform.servoChannel(pin) != null;
}

/// Reports whether Timer1 is in use.
pub fn isActive() bool {
    return active;
}

/// Initializes servo output.
pub fn init(comptime pin: gpio.Pin) void {
    comptime ensureSupported(pin);

    regs.TC1.TCCR1B.modify(.{ .CS1 = 0, .WGM1 = 0 });
    regs.TC1.TCCR1A.modify(.{ .WGM1 = 0, .COM1A = 0, .COM1B = 0 });
    regs.TC1.TCNT1.* = 0;
    regs.TC1.ICR1.* = timer1_top;
    regs.TC1.OCR1A.* = 0;
    regs.TC1.OCR1B.* = 0;

    gpio.init(pin, .out);
    enableChannel(pin);
    regs.TC1.TCCR1A.modify(.{ .WGM1 = fast_pwm_icr1_wgm_low });
    regs.TC1.TCCR1B.modify(.{ .CS1 = timer1_clock_select, .WGM1 = fast_pwm_icr1_wgm_high });

    active = true;
    writeMicros(pin, center_pulse_us);
}

/// Stops servo output.
pub fn deinit() void {
    regs.TC1.TCCR1B.modify(.{ .CS1 = 0, .WGM1 = 0 });
    regs.TC1.TCCR1A.modify(.{ .WGM1 = 0, .COM1A = 0, .COM1B = 0 });
    regs.TC1.OCR1A.* = 0;
    regs.TC1.OCR1B.* = 0;
    active = false;
}

/// Sets the pulse width.
pub fn writeMicros(comptime pin: gpio.Pin, pulse_us: u16) void {
    comptime ensureSupported(pin);

    const clamped = clampPulse(pulse_us);
    const ticks: u16 = @intCast(@as(u32, clamped) * ticks_per_us);

    switch (platform.servoChannel(pin).?) {
        .timer1_a => regs.TC1.OCR1A.* = ticks,
        .timer1_b => regs.TC1.OCR1B.* = ticks,
        else => unreachable,
    }
}

/// Sets the angle in degrees.
pub fn writeDegrees(comptime pin: gpio.Pin, degrees: u8) void {
    comptime ensureSupported(pin);

    const clamped_degrees: u8 = if (degrees > 180) 180 else degrees;
    const span_us = max_pulse_us - min_pulse_us;
    const pulse_us = min_pulse_us + @as(u16, @intCast((@as(u32, span_us) * clamped_degrees) / 180));
    writeMicros(pin, pulse_us);
}

fn ensureSupported(comptime pin: gpio.Pin) void {
    if (!supports(pin)) {
        @compileError("servo: unsupported pin for the selected board");
    }
}

fn clampPulse(pulse_us: u16) u16 {
    if (pulse_us < min_pulse_us) return min_pulse_us;
    if (pulse_us > max_pulse_us) return max_pulse_us;
    return pulse_us;
}

fn enableChannel(comptime pin: gpio.Pin) void {
    switch (platform.servoChannel(pin).?) {
        .timer1_a => regs.TC1.TCCR1A.modify(.{ .COM1A = non_inverting_compare_output }),
        .timer1_b => regs.TC1.TCCR1A.modify(.{ .COM1B = non_inverting_compare_output }),
        else => unreachable,
    }
}
