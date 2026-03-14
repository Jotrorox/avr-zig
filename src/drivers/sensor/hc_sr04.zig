const gpio = @import("../../hal/gpio.zig");
const servo = @import("../actuator/servo.zig");
const platform = @import("../../platform/current.zig");
const regs = platform.registers;

const trigger_pulse_us: u16 = 10;
const pre_trigger_settle_us: u16 = 4;
const echo_start_timeout_ticks: u16 = 60_000;
const echo_end_timeout_ticks: u16 = 60_000;
const cycles_per_us = platform.CPU_FREQ / 1_000_000;
const timer1_clock_select = 0b010;

pub const Error = error{
    EchoStartTimeout,
    EchoEndTimeout,
    Timer1Unavailable,
};

pub const Reading = struct {
    pulse_width_us: u16,
    distance_cm: u16,
};

/// Initializes the sensor pins.
pub fn init(comptime echo_pin: gpio.Pin, comptime trig_pin: gpio.Pin) void {
    comptime ensureDistinctPins(echo_pin, trig_pin);

    gpio.init(trig_pin, .out);
    gpio.write(trig_pin, false);
    gpio.init(echo_pin, .in);
    gpio.setPullup(echo_pin, false);
}

/// Reads one distance sample.
pub fn read(comptime echo_pin: gpio.Pin, comptime trig_pin: gpio.Pin) Error!Reading {
    init(echo_pin, trig_pin);
    if (servo.isActive()) {
        return error.Timer1Unavailable;
    }

    const timer1_state = saveTimer1State();
    defer restoreTimer1State(timer1_state);

    prepareTimer1();
    sendTriggerPulse(trig_pin);

    regs.TC1.TCNT1.* = 0;
    try waitForEdgeWithTimer(echo_pin, true, echo_start_timeout_ticks, error.EchoStartTimeout);

    regs.TC1.TCNT1.* = 0;
    try waitForEdgeWithTimer(echo_pin, false, echo_end_timeout_ticks, error.EchoEndTimeout);

    const pulse_ticks = regs.TC1.TCNT1.*;
    const pulse_width_us = ticksToMicroseconds(pulse_ticks);

    return .{
        .pulse_width_us = pulse_width_us,
        .distance_cm = pulseWidthToCentimeters(pulse_width_us),
    };
}

const Timer1State = struct {
    tccr1a_wgm1: u2,
    tccr1b_wgm1: u2,
    tccr1b_cs1: u3,
};

fn ensureDistinctPins(comptime echo_pin: gpio.Pin, comptime trig_pin: gpio.Pin) void {
    if (echo_pin == trig_pin) {
        @compileError("HC-SR04 echo and trig pins must be different");
    }
}

fn sendTriggerPulse(comptime trig_pin: gpio.Pin) void {
    gpio.write(trig_pin, false);
    delayUs(pre_trigger_settle_us);
    gpio.write(trig_pin, true);
    delayUs(trigger_pulse_us);
    gpio.write(trig_pin, false);
}

fn waitForEdgeWithTimer(
    comptime pin: gpio.Pin,
    expected: bool,
    timeout_ticks: u16,
    err: Error,
) Error!void {
    while (gpio.read(pin) != expected) {
        if (regs.TC1.TCNT1.* >= timeout_ticks) {
            return err;
        }
    }
}

fn saveTimer1State() Timer1State {
    const tccr1a = regs.TC1.TCCR1A.read();
    const tccr1b = regs.TC1.TCCR1B.read();

    return .{
        .tccr1a_wgm1 = tccr1a.WGM1,
        .tccr1b_wgm1 = tccr1b.WGM1,
        .tccr1b_cs1 = tccr1b.CS1,
    };
}

fn restoreTimer1State(state: Timer1State) void {
    regs.TC1.TCCR1B.modify(.{ .CS1 = 0, .WGM1 = 0 });
    regs.TC1.TCCR1A.modify(.{ .WGM1 = state.tccr1a_wgm1 });
    regs.TC1.TCCR1B.modify(.{ .CS1 = state.tccr1b_cs1, .WGM1 = state.tccr1b_wgm1 });
}

fn prepareTimer1() void {
    regs.TC1.TCCR1B.modify(.{ .CS1 = 0, .WGM1 = 0 });
    regs.TC1.TCCR1A.modify(.{ .WGM1 = 0 });
    regs.TC1.TCNT1.* = 0;
    regs.TC1.TIFR1.modify(.{ .TOV1 = 1 });
    regs.TC1.TCCR1B.modify(.{ .CS1 = timer1_clock_select, .WGM1 = 0 });
}

fn ticksToMicroseconds(pulse_ticks: u16) u16 {
    var pulse_width_us = pulse_ticks >> 1;
    if ((pulse_ticks & 1) != 0) {
        pulse_width_us +%= 1;
    }
    return pulse_width_us;
}

fn pulseWidthToCentimeters(pulse_width_us: u16) u16 {
    return (pulse_width_us >> 6) + (pulse_width_us >> 9) - (pulse_width_us >> 12);
}

fn delayUs(us: u16) void {
    var remaining = us;
    while (remaining > 0) : (remaining -= 1) {
        inline for (0..cycles_per_us) |_| {
            asm volatile ("nop");
        }
    }
}
