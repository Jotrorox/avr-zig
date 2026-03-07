const uno = @import("../board/uno.zig");
const regs = @import("../mcu/atmega328p.zig").registers;

pub const default_clock_hz = 100_000;

const sda_pin = @as(u7, 1 << 4);
const scl_pin = @as(u7, 1 << 5);
const twi_pins = sda_pin | scl_pin;

pub fn init() void {
    initWithFrequency(default_clock_hz);
}

pub fn initWithFrequency(comptime clock_hz: comptime_int) void {
    if (clock_hz <= 0) {
        @compileError("I2C clock must be greater than zero");
    }

    if (clock_hz > uno.CPU_FREQ / 16) {
        @compileError("I2C clock is too high for the configured CPU frequency");
    }

    const twbr_value = (uno.CPU_FREQ / clock_hz - 16) / 2;
    if (twbr_value > 255) {
        @compileError("Computed TWBR value does not fit in 8 bits");
    }

    // SDA/SCL must be inputs for the TWI peripheral. Enabling the pull-ups
    // makes the bus usable without external resistors for short test setups.
    regs.PORTC.DDRC.* &= ~twi_pins;
    regs.PORTC.PORTC.* |= twi_pins;

    regs.TWI.TWSR.modify(.{ .TWPS = 0 });
    regs.TWI.TWBR.* = @as(u8, @intCast(twbr_value));
    regs.TWI.TWCR.modify(.{
        .TWIE = 0,
        .TWEN = 1,
        .TWEA = 0,
        .TWINT = 0,
        .TWSTA = 0,
        .TWSTO = 0,
    });
}

pub fn probe(address: u7) bool {
    if (!startWrite(address)) {
        return false;
    }

    stop();
    return true;
}

pub fn scan(comptime on_found: fn (u7) void) usize {
    var count: usize = 0;
    var address: u8 = 0x08;
    while (address < 0x78) : (address += 1) {
        const candidate = @as(u7, @intCast(address));
        if (probe(candidate)) {
            on_found(candidate);
            count += 1;
        }
    }

    return count;
}

pub fn startWrite(address: u7) bool {
    if (!sendStart()) {
        sendStop();
        return false;
    }

    const status = writeByte(@as(u8, address) << 1);
    if (status != 0x18) {
        sendStop();
        return false;
    }

    return true;
}

pub fn writeData(byte: u8) bool {
    return writeByte(byte) == 0x28;
}

pub fn write(address: u7, bytes: []const u8) bool {
    if (!startWrite(address)) {
        return false;
    }

    var index: usize = 0;
    while (index < bytes.len) : (index += 1) {
        if (!writeData(bytes[index])) {
            stop();
            return false;
        }
    }

    stop();
    return true;
}

pub fn stop() void {
    sendStop();
}

fn sendStart() bool {
    regs.TWI.TWCR.modify(.{
        .TWINT = 1,
        .TWSTA = 1,
        .TWSTO = 0,
        .TWEN = 1,
    });
    waitForTwint();

    const status = readStatus();
    return status == 0x08 or status == 0x10;
}

fn sendStop() void {
    regs.TWI.TWCR.modify(.{
        .TWINT = 1,
        .TWSTA = 0,
        .TWSTO = 1,
        .TWEN = 1,
    });

    while (regs.TWI.TWCR.read().TWSTO != 0) {}
}

fn writeByte(byte: u8) u8 {
    regs.TWI.TWDR.* = byte;
    regs.TWI.TWCR.modify(.{
        .TWINT = 1,
        .TWSTA = 0,
        .TWSTO = 0,
        .TWEN = 1,
    });
    waitForTwint();
    return readStatus();
}

fn waitForTwint() void {
    while (regs.TWI.TWCR.read().TWINT != 1) {}
}

fn readStatus() u8 {
    return @as(u8, regs.TWI.TWSR.read().TWS) << 3;
}
