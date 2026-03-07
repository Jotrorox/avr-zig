const regs = @import("../mcu/atmega328p.zig").registers;

pub const Direction = enum { in, out };

// PORTB: pins D8 to D13
fn init_portb(pin: u3, comptime dir: Direction) void {
    const mask = @as(u8, 1) << pin;
    if (dir == .out) {
        regs.PORTB.DDRB.* |= mask;
    } else {
        regs.PORTB.DDRB.* &= ~mask;
    }
}

fn toggle_portb(comptime pin: u3) void {
    var val = regs.PORTB.PORTB.*;
    val ^= 1 << pin;
    regs.PORTB.PORTB.* = val;
}

// PORTD: pins D0 TO D7
fn init_portd(pin: u3, comptime dir: Direction) void {
    const mask = @as(u8, 1) << pin;
    if (dir == .out) {
        regs.PORTD.DDRD.* |= mask;
    } else {
        regs.PORTD.DDRD.* &= ~mask;
    }
}

fn toggle_portd(comptime pin: u3) void {
    var val = regs.PORTD.PORTD.*;
    val ^= 1 << pin;
    regs.PORTD.PORTD.* = val;
}

// PORTC: pins A0 TO D5
fn init_portc(pin: u3, comptime dir: Direction) void {
    const mask = @as(u8, 1) << pin;
    if (dir == .out) {
        regs.PORTC.DDRC.* |= mask;
    } else {
        regs.PORTC.DDRC.* &= ~mask;
    }
}

fn toggle_portc(comptime pin: u3) void {
    var val = regs.PORTC.PORTC.*;
    val ^= 1 << pin;
    regs.PORTC.PORTC.* = val;
}

pub const Pin = enum {
    D0,
    D1,
    D2,
    D3,
    D4,
    D5,
    D6,
    D7,
    D8,
    D9,
    D10,
    D11,
    D12,
    D13,
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
};

pub fn init(comptime pin: Pin, comptime dir: Direction) void {
    const i = @intFromEnum(pin);
    if (i <= 7) {
        init_portd(@as(u3, @intCast(i)), dir);
    } else if (i >= 8 and i <= 13) {
        init_portb(@as(u3, @intCast(i - 8)), dir);
    } else if (i >= 14) {
        init_portc(@as(u3, @intCast(i - 14)), dir);
    }
}

pub fn toggle(comptime pin: Pin) void {
    const i = comptime @intFromEnum(pin);
    if (i <= 7) {
        toggle_portd(@as(u3, @intCast(i)));
    } else if (i >= 8 and i <= 13) {
        toggle_portb(@as(u3, @intCast(i - 8)));
    } else if (i >= 14) {
        toggle_portc(@as(u3, @intCast(i - 14)));
    }
}
