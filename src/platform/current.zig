const builtin = @import("builtin");
const std = @import("std");

const uno_board = @import("../board/uno.zig");
const mega_board = @import("../board/mega2560.zig");
const atmega328p = @import("../mcu/atmega328p.zig");
const atmega2560 = @import("../mcu/atmega2560.zig");

pub const Board = enum {
    uno,
    mega2560,
};

pub const current_board: Board = blk: {
    if (builtin.target.cpu.arch != .avr) {
        @compileError("avr_zig supports only AVR freestanding targets");
    }

    if (std.mem.eql(u8, builtin.target.cpu.model.name, "atmega328p")) {
        break :blk .uno;
    }

    if (std.mem.eql(u8, builtin.target.cpu.model.name, "atmega2560")) {
        break :blk .mega2560;
    }

    @compileError(std.fmt.comptimePrint(
        "avr_zig supports only ATmega328P and ATmega2560, found '{s}'",
        .{builtin.target.cpu.model.name},
    ));
};

pub const board = switch (current_board) {
    .uno => uno_board,
    .mega2560 => mega_board,
};

pub const mcu = switch (current_board) {
    .uno => atmega328p,
    .mega2560 => atmega2560,
};

pub const registers = mcu.registers;
pub const VectorTable = mcu.VectorTable;
pub const CPU_FREQ = board.CPU_FREQ;

pub const Port = enum {
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    J,
    K,
    L,
};

pub const PinDesc = struct {
    port: Port,
    bit: u3,
};

pub const AnalogInputDisable = struct {
    register: enum { didr0, didr2 },
    bit: u3,
};

pub const PwmChannel = enum {
    timer1_a,
    timer1_b,
    timer2_a,
    timer2_b,
};

pub const ServoChannel = enum {
    timer1_a,
    timer1_b,
};

const UnoPin = enum {
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

const MegaPin = enum {
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
    D14,
    D15,
    D16,
    D17,
    D18,
    D19,
    D20,
    D21,
    D22,
    D23,
    D24,
    D25,
    D26,
    D27,
    D28,
    D29,
    D30,
    D31,
    D32,
    D33,
    D34,
    D35,
    D36,
    D37,
    D38,
    D39,
    D40,
    D41,
    D42,
    D43,
    D44,
    D45,
    D46,
    D47,
    D48,
    D49,
    D50,
    D51,
    D52,
    D53,
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
    A6,
    A7,
    A8,
    A9,
    A10,
    A11,
    A12,
    A13,
    A14,
    A15,
};

const UnoAnalogPin = enum {
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
};

const MegaAnalogPin = enum {
    A0,
    A1,
    A2,
    A3,
    A4,
    A5,
    A6,
    A7,
    A8,
    A9,
    A10,
    A11,
    A12,
    A13,
    A14,
    A15,
};

pub const Pin = switch (current_board) {
    .uno => UnoPin,
    .mega2560 => MegaPin,
};

pub const AnalogPin = switch (current_board) {
    .uno => UnoAnalogPin,
    .mega2560 => MegaAnalogPin,
};

pub const spi_pins = switch (current_board) {
    .uno => .{ .ss = Pin.D10, .mosi = Pin.D11, .miso = Pin.D12, .sck = Pin.D13 },
    .mega2560 => .{ .ss = Pin.D53, .mosi = Pin.D51, .miso = Pin.D50, .sck = Pin.D52 },
};

pub const i2c_pins = switch (current_board) {
    .uno => .{ .sda = Pin.A4, .scl = Pin.A5 },
    .mega2560 => .{ .sda = Pin.D20, .scl = Pin.D21 },
};

pub fn pinDesc(comptime pin: Pin) PinDesc {
    return switch (current_board) {
        .uno => switch (pin) {
            .D0 => .{ .port = .D, .bit = 0 },
            .D1 => .{ .port = .D, .bit = 1 },
            .D2 => .{ .port = .D, .bit = 2 },
            .D3 => .{ .port = .D, .bit = 3 },
            .D4 => .{ .port = .D, .bit = 4 },
            .D5 => .{ .port = .D, .bit = 5 },
            .D6 => .{ .port = .D, .bit = 6 },
            .D7 => .{ .port = .D, .bit = 7 },
            .D8 => .{ .port = .B, .bit = 0 },
            .D9 => .{ .port = .B, .bit = 1 },
            .D10 => .{ .port = .B, .bit = 2 },
            .D11 => .{ .port = .B, .bit = 3 },
            .D12 => .{ .port = .B, .bit = 4 },
            .D13 => .{ .port = .B, .bit = 5 },
            .A0 => .{ .port = .C, .bit = 0 },
            .A1 => .{ .port = .C, .bit = 1 },
            .A2 => .{ .port = .C, .bit = 2 },
            .A3 => .{ .port = .C, .bit = 3 },
            .A4 => .{ .port = .C, .bit = 4 },
            .A5 => .{ .port = .C, .bit = 5 },
        },
        .mega2560 => switch (pin) {
            .D0 => .{ .port = .E, .bit = 0 },
            .D1 => .{ .port = .E, .bit = 1 },
            .D2 => .{ .port = .E, .bit = 4 },
            .D3 => .{ .port = .E, .bit = 5 },
            .D4 => .{ .port = .G, .bit = 5 },
            .D5 => .{ .port = .E, .bit = 3 },
            .D6 => .{ .port = .H, .bit = 3 },
            .D7 => .{ .port = .H, .bit = 4 },
            .D8 => .{ .port = .H, .bit = 5 },
            .D9 => .{ .port = .H, .bit = 6 },
            .D10 => .{ .port = .B, .bit = 4 },
            .D11 => .{ .port = .B, .bit = 5 },
            .D12 => .{ .port = .B, .bit = 6 },
            .D13 => .{ .port = .B, .bit = 7 },
            .D14 => .{ .port = .J, .bit = 1 },
            .D15 => .{ .port = .J, .bit = 0 },
            .D16 => .{ .port = .H, .bit = 1 },
            .D17 => .{ .port = .H, .bit = 0 },
            .D18 => .{ .port = .D, .bit = 3 },
            .D19 => .{ .port = .D, .bit = 2 },
            .D20 => .{ .port = .D, .bit = 1 },
            .D21 => .{ .port = .D, .bit = 0 },
            .D22 => .{ .port = .A, .bit = 0 },
            .D23 => .{ .port = .A, .bit = 1 },
            .D24 => .{ .port = .A, .bit = 2 },
            .D25 => .{ .port = .A, .bit = 3 },
            .D26 => .{ .port = .A, .bit = 4 },
            .D27 => .{ .port = .A, .bit = 5 },
            .D28 => .{ .port = .A, .bit = 6 },
            .D29 => .{ .port = .A, .bit = 7 },
            .D30 => .{ .port = .C, .bit = 7 },
            .D31 => .{ .port = .C, .bit = 6 },
            .D32 => .{ .port = .C, .bit = 5 },
            .D33 => .{ .port = .C, .bit = 4 },
            .D34 => .{ .port = .C, .bit = 3 },
            .D35 => .{ .port = .C, .bit = 2 },
            .D36 => .{ .port = .C, .bit = 1 },
            .D37 => .{ .port = .C, .bit = 0 },
            .D38 => .{ .port = .D, .bit = 7 },
            .D39 => .{ .port = .G, .bit = 2 },
            .D40 => .{ .port = .G, .bit = 1 },
            .D41 => .{ .port = .G, .bit = 0 },
            .D42 => .{ .port = .L, .bit = 7 },
            .D43 => .{ .port = .L, .bit = 6 },
            .D44 => .{ .port = .L, .bit = 5 },
            .D45 => .{ .port = .L, .bit = 4 },
            .D46 => .{ .port = .L, .bit = 3 },
            .D47 => .{ .port = .L, .bit = 2 },
            .D48 => .{ .port = .L, .bit = 1 },
            .D49 => .{ .port = .L, .bit = 0 },
            .D50 => .{ .port = .B, .bit = 3 },
            .D51 => .{ .port = .B, .bit = 2 },
            .D52 => .{ .port = .B, .bit = 1 },
            .D53 => .{ .port = .B, .bit = 0 },
            .A0 => .{ .port = .F, .bit = 0 },
            .A1 => .{ .port = .F, .bit = 1 },
            .A2 => .{ .port = .F, .bit = 2 },
            .A3 => .{ .port = .F, .bit = 3 },
            .A4 => .{ .port = .F, .bit = 4 },
            .A5 => .{ .port = .F, .bit = 5 },
            .A6 => .{ .port = .F, .bit = 6 },
            .A7 => .{ .port = .F, .bit = 7 },
            .A8 => .{ .port = .K, .bit = 0 },
            .A9 => .{ .port = .K, .bit = 1 },
            .A10 => .{ .port = .K, .bit = 2 },
            .A11 => .{ .port = .K, .bit = 3 },
            .A12 => .{ .port = .K, .bit = 4 },
            .A13 => .{ .port = .K, .bit = 5 },
            .A14 => .{ .port = .K, .bit = 6 },
            .A15 => .{ .port = .K, .bit = 7 },
        },
    };
}

pub fn analogChannel(comptime pin: AnalogPin) u5 {
    return switch (current_board) {
        .uno => switch (pin) {
            .A0 => 0,
            .A1 => 1,
            .A2 => 2,
            .A3 => 3,
            .A4 => 4,
            .A5 => 5,
        },
        .mega2560 => switch (pin) {
            .A0 => 0,
            .A1 => 1,
            .A2 => 2,
            .A3 => 3,
            .A4 => 4,
            .A5 => 5,
            .A6 => 6,
            .A7 => 7,
            .A8 => 8,
            .A9 => 9,
            .A10 => 10,
            .A11 => 11,
            .A12 => 12,
            .A13 => 13,
            .A14 => 14,
            .A15 => 15,
        },
    };
}

pub fn analogDigitalPin(comptime pin: AnalogPin) Pin {
    return switch (current_board) {
        .uno => switch (pin) {
            .A0 => .A0,
            .A1 => .A1,
            .A2 => .A2,
            .A3 => .A3,
            .A4 => .A4,
            .A5 => .A5,
        },
        .mega2560 => switch (pin) {
            .A0 => .A0,
            .A1 => .A1,
            .A2 => .A2,
            .A3 => .A3,
            .A4 => .A4,
            .A5 => .A5,
            .A6 => .A6,
            .A7 => .A7,
            .A8 => .A8,
            .A9 => .A9,
            .A10 => .A10,
            .A11 => .A11,
            .A12 => .A12,
            .A13 => .A13,
            .A14 => .A14,
            .A15 => .A15,
        },
    };
}

pub fn analogInputDisable(comptime pin: AnalogPin) AnalogInputDisable {
    return switch (current_board) {
        .uno => .{ .register = .didr0, .bit = @as(u3, @intCast(analogChannel(pin))) },
        .mega2560 => blk: {
            const channel = analogChannel(pin);
            if (channel < 8) {
                break :blk .{ .register = .didr0, .bit = @as(u3, @intCast(channel)) };
            }
            break :blk .{ .register = .didr2, .bit = @as(u3, @intCast(channel - 8)) };
        },
    };
}

pub fn pwmChannel(comptime pin: Pin) ?PwmChannel {
    return switch (current_board) {
        .uno => switch (pin) {
            .D9 => .timer1_a,
            .D10 => .timer1_b,
            .D11 => .timer2_a,
            .D3 => .timer2_b,
            else => null,
        },
        .mega2560 => switch (pin) {
            .D11 => .timer1_a,
            .D12 => .timer1_b,
            .D10 => .timer2_a,
            .D9 => .timer2_b,
            else => null,
        },
    };
}

pub fn usesReservedTimer0Pwm(comptime pin: Pin) bool {
    return switch (current_board) {
        .uno => switch (pin) {
            .D5, .D6 => true,
            else => false,
        },
        .mega2560 => switch (pin) {
            .D4, .D13 => true,
            else => false,
        },
    };
}

pub fn servoChannel(comptime pin: Pin) ?ServoChannel {
    return switch (current_board) {
        .uno => switch (pin) {
            .D9 => .timer1_a,
            .D10 => .timer1_b,
            else => null,
        },
        .mega2560 => switch (pin) {
            .D11 => .timer1_a,
            .D12 => .timer1_b,
            else => null,
        },
    };
}

pub fn portInputRegister(comptime port: Port) *volatile u8 {
    return switch (current_board) {
        .uno => switch (port) {
            .B => registers.PORTB.PINB,
            .C => registers.PORTC.PINC,
            .D => registers.PORTD.PIND,
            else => @compileError("port is not available on the Uno"),
        },
        .mega2560 => switch (port) {
            .A => registers.PORTA.PINA,
            .B => registers.PORTB.PINB,
            .C => registers.PORTC.PINC,
            .D => registers.PORTD.PIND,
            .E => registers.PORTE.PINE,
            .F => registers.PORTF.PINF,
            .G => registers.PORTG.PING,
            .H => registers.PORTH.PINH,
            .J => registers.PORTJ.PINJ,
            .K => registers.PORTK.PINK,
            .L => registers.PORTL.PINL,
        },
    };
}

pub fn portDirectionRegister(comptime port: Port) *volatile u8 {
    return switch (current_board) {
        .uno => switch (port) {
            .B => registers.PORTB.DDRB,
            .C => registers.PORTC.DDRC,
            .D => registers.PORTD.DDRD,
            else => @compileError("port is not available on the Uno"),
        },
        .mega2560 => switch (port) {
            .A => registers.PORTA.DDRA,
            .B => registers.PORTB.DDRB,
            .C => registers.PORTC.DDRC,
            .D => registers.PORTD.DDRD,
            .E => registers.PORTE.DDRE,
            .F => registers.PORTF.DDRF,
            .G => registers.PORTG.DDRG,
            .H => registers.PORTH.DDRH,
            .J => registers.PORTJ.DDRJ,
            .K => registers.PORTK.DDRK,
            .L => registers.PORTL.DDRL,
        },
    };
}

pub fn portOutputRegister(comptime port: Port) *volatile u8 {
    return switch (current_board) {
        .uno => switch (port) {
            .B => registers.PORTB.PORTB,
            .C => registers.PORTC.PORTC,
            .D => registers.PORTD.PORTD,
            else => @compileError("port is not available on the Uno"),
        },
        .mega2560 => switch (port) {
            .A => registers.PORTA.PORTA,
            .B => registers.PORTB.PORTB,
            .C => registers.PORTC.PORTC,
            .D => registers.PORTD.PORTD,
            .E => registers.PORTE.PORTE,
            .F => registers.PORTF.PORTF,
            .G => registers.PORTG.PORTG,
            .H => registers.PORTH.PORTH,
            .J => registers.PORTJ.PORTJ,
            .K => registers.PORTK.PORTK,
            .L => registers.PORTL.PORTL,
        },
    };
}

pub fn pinInputRegister(comptime pin: Pin) *volatile u8 {
    return portInputRegister(pinDesc(pin).port);
}

pub fn pinDirectionRegister(comptime pin: Pin) *volatile u8 {
    return portDirectionRegister(pinDesc(pin).port);
}

pub fn pinOutputRegister(comptime pin: Pin) *volatile u8 {
    return portOutputRegister(pinDesc(pin).port);
}

pub fn pinMask(comptime pin: Pin) u8 {
    return @as(u8, 1) << pinDesc(pin).bit;
}
