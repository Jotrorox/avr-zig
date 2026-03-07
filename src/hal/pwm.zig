const uno = @import("../board/uno.zig");
const gpio = @import("gpio.zig");
const regs = @import("../mcu/atmega328p.zig").registers;

pub const max_duty = 255;

const timer_prescaler = 64;
const timer1_clock_select = 0b011;
const timer2_clock_select = 0b100;
const non_inverting_compare_output = 0b10;
pub const default_frequency_hz = uno.CPU_FREQ / timer_prescaler / 256;

var timer1_initialized = false;
var timer2_initialized = false;

const Channel = enum {
    timer1_a,
    timer1_b,
    timer2_a,
    timer2_b,
};

pub fn supports(comptime pin: gpio.Pin) bool {
    return switch (pin) {
        .D3, .D9, .D10, .D11 => true,
        else => false,
    };
}

pub fn init(comptime pin: gpio.Pin) void {
    const channel = comptime channelForPin(pin);

    switch (channel) {
        .timer1_a, .timer1_b => ensureTimer1(),
        .timer2_a, .timer2_b => ensureTimer2(),
    }

    gpio.init(pin, .out);
    enableChannel(channel);
    write(pin, 0);
}

pub fn write(comptime pin: gpio.Pin, duty: u8) void {
    const channel = comptime channelForPin(pin);

    switch (channel) {
        .timer1_a => regs.TC1.OCR1A.* = duty,
        .timer1_b => regs.TC1.OCR1B.* = duty,
        .timer2_a => regs.TC2.OCR2A.* = duty,
        .timer2_b => regs.TC2.OCR2B.* = duty,
    }
}

fn channelForPin(comptime pin: gpio.Pin) Channel {
    return switch (pin) {
        .D9 => .timer1_a,
        .D10 => .timer1_b,
        .D11 => .timer2_a,
        .D3 => .timer2_b,
        .D5, .D6 => @compileError("pwm: D5 and D6 use Timer0, which is reserved by hal.time"),
        else => @compileError("pwm: unsupported pin, use one of D3, D9, D10, or D11"),
    };
}

fn ensureTimer1() void {
    if (timer1_initialized) return;

    regs.TC1.TCCR1B.modify(.{ .CS1 = 0, .WGM1 = 0b01 });
    regs.TC1.TCCR1A.modify(.{ .WGM1 = 0b01 });
    regs.TC1.TCNT1.* = 0;
    regs.TC1.OCR1A.* = 0;
    regs.TC1.OCR1B.* = 0;
    regs.TC1.TCCR1B.modify(.{ .CS1 = timer1_clock_select, .WGM1 = 0b01 });
    timer1_initialized = true;
}

fn ensureTimer2() void {
    if (timer2_initialized) return;

    regs.TC2.ASSR.modify(.{ .AS2 = 0, .EXCLK = 0 });
    regs.TC2.TCCR2B.modify(.{ .CS2 = 0, .WGM22 = 0 });
    regs.TC2.TCCR2A.modify(.{ .WGM2 = 0b11 });
    regs.TC2.TCNT2.* = 0;
    regs.TC2.OCR2A.* = 0;
    regs.TC2.OCR2B.* = 0;
    regs.TC2.TCCR2B.modify(.{ .CS2 = timer2_clock_select, .WGM22 = 0 });
    timer2_initialized = true;
}

fn enableChannel(channel: Channel) void {
    switch (channel) {
        .timer1_a => regs.TC1.TCCR1A.modify(.{ .COM1A = non_inverting_compare_output }),
        .timer1_b => regs.TC1.TCCR1A.modify(.{ .COM1B = non_inverting_compare_output }),
        .timer2_a => regs.TC2.TCCR2A.modify(.{ .COM2A = non_inverting_compare_output }),
        .timer2_b => regs.TC2.TCCR2A.modify(.{ .COM2B = non_inverting_compare_output }),
    }
}
