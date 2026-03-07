const uno = @import("../board/uno.zig");
const regs = @import("../mcu/atmega328p.zig").registers;

const ubrr0_value = blk: {
    const oversample = 8;
    break :blk @as(u16, (uno.CPU_FREQ / (oversample * baud_rate)) - 1);
};

const baud_rate = 115200;

pub fn init(comptime baud: comptime_int) void {
    if (baud != baud_rate) {
        @compileError("uart.init currently supports only 115200 baud on this Zig toolchain");
    }

    // Set baudrate
    regs.USART0.UBRR0.* = ubrr0_value;

    // Default uart settings are 8n1, so no need to change them!
    regs.USART0.UCSR0A.modify(.{ .U2X0 = 1 });

    // Enable transmitter!
    regs.USART0.UCSR0B.modify(.{ .TXEN0 = 1 });
}

pub fn write(data: []const u8) void {
    for (data) |ch| {
        write_ch(ch);
    }

    // Wait till we are actually done sending
    while (regs.USART0.UCSR0A.read().TXC0 != 1) {}
}

pub fn write_ch(ch: u8) void {
    // Wait till the transmit buffer is empty
    while (regs.USART0.UCSR0A.read().UDRE0 != 1) {}

    regs.USART0.UDR0.* = ch;
}
