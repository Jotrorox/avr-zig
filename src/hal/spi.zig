const regs = @import("../mcu/atmega328p.zig").registers;

const ss_mask = @as(u8, 1 << 2);
const mosi_mask = @as(u8, 1 << 3);
const miso_mask = @as(u8, 1 << 4);
const sck_mask = @as(u8, 1 << 5);

pub const ClockDiv = enum {
    f2,
    f4,
    f8,
    f16,
    f32,
    f64,
    f128,
};

pub fn init(comptime clock_div: ClockDiv) void {
    regs.PORTB.DDRB.* |= ss_mask | mosi_mask | sck_mask;
    regs.PORTB.DDRB.* &= ~miso_mask;

    // Keeping the hardware SS pin as an output prevents the AVR from
    // dropping back into slave mode while the MFRC522 uses D10 as chip select.
    regs.PORTB.PORTB.* |= ss_mask;

    const config = divConfig(clock_div);
    regs.SPI.SPSR.modify(.{ .SPI2X = config.spi2x });
    regs.SPI.SPCR.modify(.{
        .SPR = config.spr,
        .CPHA = 0,
        .CPOL = 0,
        .MSTR = 1,
        .DORD = 0,
        .SPE = 1,
        .SPIE = 0,
    });
}

pub fn transfer(byte: u8) u8 {
    regs.SPI.SPDR.* = byte;
    while (regs.SPI.SPSR.read().SPIF != 1) {}
    return regs.SPI.SPDR.*;
}

fn divConfig(comptime clock_div: ClockDiv) struct { spr: u2, spi2x: u1 } {
    return switch (clock_div) {
        .f2 => .{ .spr = 0b00, .spi2x = 1 },
        .f4 => .{ .spr = 0b00, .spi2x = 0 },
        .f8 => .{ .spr = 0b01, .spi2x = 1 },
        .f16 => .{ .spr = 0b01, .spi2x = 0 },
        .f32 => .{ .spr = 0b10, .spi2x = 1 },
        .f64 => .{ .spr = 0b10, .spi2x = 0 },
        .f128 => .{ .spr = 0b11, .spi2x = 0 },
    };
}
