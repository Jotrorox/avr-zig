const gpio = @import("../../hal/gpio.zig");
const spi = @import("../../hal/spi.zig");
const time = @import("../../hal/time.zig");

const command_idle = 0x00;
const command_calc_crc = 0x03;
const command_transceive = 0x0C;
const command_soft_reset = 0x0F;

const picc_cmd_reqa = 0x26;
const picc_cmd_sel_cl1 = 0x93;
const picc_cmd_anticoll_cl1 = 0x20;
const picc_cmd_select_cl1 = 0x70;
const picc_cmd_hlta = 0x50;

const irq_transceive = 0x30;
const irq_crc = 0x04;
const irq_timer = 0x01;

const tx_start_send = 0x80;
const flush_fifo = 0x80;
const values_after_collision = 0x80;
const antenna_enable = 0x03;

const timer_prescaler = 0xA9;
const timer_reload_high = 0x03;
const timer_reload_low = 0xE8;

const Register = enum(u8) {
    Command = 0x01,
    ComIrq = 0x04,
    DivIrq = 0x05,
    Error = 0x06,
    FIFOData = 0x09,
    FIFOLevel = 0x0A,
    Control = 0x0C,
    BitFraming = 0x0D,
    Coll = 0x0E,
    Mode = 0x11,
    TxMode = 0x12,
    RxMode = 0x13,
    TxControl = 0x14,
    TxASK = 0x15,
    CRCResultHigh = 0x21,
    CRCResultLow = 0x22,
    ModWidth = 0x24,
    TMode = 0x2A,
    TPrescaler = 0x2B,
    TReloadHigh = 0x2C,
    TReloadLow = 0x2D,
    Version = 0x37,
};

pub const Error = error{
    NoCard,
    Timeout,
    Collision,
    Communication,
    BufferTooSmall,
    Protocol,
    Crc,
    UnsupportedUid,
};

pub const Uid = struct {
    bytes: [4]u8,
    len: u8,
    sak: u8,
};

pub fn Device(comptime cs_pin: gpio.Pin, comptime rst_pin: gpio.Pin) type {
    comptime ensureDistinctPins(cs_pin, rst_pin);

    return struct {
        const Self = @This();

        pub fn init(self: *Self) void {
            spi.init(.f16);
            gpio.init(cs_pin, .out);
            gpio.init(rst_pin, .out);

            gpio.write(cs_pin, true);
            gpio.write(rst_pin, false);
            time.sleep(10);
            gpio.write(rst_pin, true);
            time.sleep(50);

            self.writeRegister(.Command, command_soft_reset);
            time.sleep(50);

            self.writeRegister(.TxMode, 0x00);
            self.writeRegister(.RxMode, 0x00);
            self.writeRegister(.ModWidth, 0x26);
            self.writeRegister(.TMode, 0x80);
            self.writeRegister(.TPrescaler, timer_prescaler);
            self.writeRegister(.TReloadHigh, timer_reload_high);
            self.writeRegister(.TReloadLow, timer_reload_low);
            self.writeRegister(.TxASK, 0x40);
            self.writeRegister(.Mode, 0x3D);
            self.clearBitMask(.Coll, values_after_collision);
            self.antennaOn();
        }

        pub fn version(self: *Self) u8 {
            return self.readRegister(.Version);
        }

        pub fn isCardPresent(self: *Self) bool {
            _ = self.requestA() catch return false;
            return true;
        }

        pub fn requestA(self: *Self) Error![2]u8 {
            var response: [2]u8 = undefined;
            var rx_last_bits: u8 = 0;
            const command = [_]u8{picc_cmd_reqa};

            const response_len = self.transceive(@ptrCast(&command), command.len, 7, @ptrCast(&response), response.len, &rx_last_bits) catch |err| switch (err) {
                error.Timeout => return error.NoCard,
                else => return err,
            };

            if (response_len != 2 or rx_last_bits != 0) {
                return error.Protocol;
            }

            return response;
        }

        pub fn readUid(self: *Self) Error!Uid {
            _ = try self.requestA();
            return self.selectCascadeLevel1();
        }

        pub fn haltA(self: *Self) void {
            var frame = [_]u8{ picc_cmd_hlta, 0x00, 0x00, 0x00 };
            const crc = self.calculateCrc(@ptrCast(&frame), 2) catch return;
            frame[2] = crc[0];
            frame[3] = crc[1];

            var response: [1]u8 = undefined;
            var rx_last_bits: u8 = 0;
            _ = self.transceive(@ptrCast(&frame), frame.len, 0, @ptrCast(&response), response.len, &rx_last_bits) catch {};
        }

        fn selectCascadeLevel1(self: *Self) Error!Uid {
            var anticollision = [_]u8{ picc_cmd_sel_cl1, picc_cmd_anticoll_cl1 };
            var anticollision_response: [5]u8 = undefined;
            var rx_last_bits: u8 = 0;

            const anticollision_len = try self.transceive(
                @ptrCast(&anticollision),
                anticollision.len,
                0,
                @ptrCast(&anticollision_response),
                anticollision_response.len,
                &rx_last_bits,
            );
            if (anticollision_len != 5 or rx_last_bits != 0) {
                return error.Protocol;
            }

            const bcc = anticollision_response[0] ^ anticollision_response[1] ^ anticollision_response[2] ^ anticollision_response[3];
            if (bcc != anticollision_response[4]) {
                return error.Crc;
            }

            var select_frame = [_]u8{ picc_cmd_sel_cl1, picc_cmd_select_cl1, 0, 0, 0, 0, 0, 0, 0 };
            const select_frame_ptr: [*]u8 = @ptrCast(&select_frame);
            const anticollision_ptr: [*]const u8 = @ptrCast(&anticollision_response);

            @setRuntimeSafety(false);
            var index: usize = 0;
            while (index < 5) : (index += 1) {
                select_frame_ptr[2 + index] = anticollision_ptr[index];
            }

            const select_crc = try self.calculateCrc(@ptrCast(&select_frame), 7);
            select_frame[7] = select_crc[0];
            select_frame[8] = select_crc[1];

            var select_response: [3]u8 = undefined;
            const select_len = try self.transceive(@ptrCast(&select_frame), select_frame.len, 0, @ptrCast(&select_response), select_response.len, &rx_last_bits);
            if (select_len != 3 or rx_last_bits != 0) {
                return error.Protocol;
            }

            var sak_frame = [_]u8{select_response[0]};
            const sak_crc = try self.calculateCrc(@ptrCast(&sak_frame), sak_frame.len);
            if (select_response[1] != sak_crc[0] or select_response[2] != sak_crc[1]) {
                return error.Crc;
            }

            if ((select_response[0] & 0x04) != 0) {
                return error.UnsupportedUid;
            }

            return .{
                .bytes = .{
                    anticollision_response[0],
                    anticollision_response[1],
                    anticollision_response[2],
                    anticollision_response[3],
                },
                .len = 4,
                .sak = select_response[0],
            };
        }

        fn calculateCrc(self: *Self, data_ptr: [*]const u8, data_len: usize) Error![2]u8 {
            self.writeRegister(.Command, command_idle);
            self.writeRegister(.DivIrq, 0x04);
            self.writeRegister(.FIFOLevel, flush_fifo);
            self.writeFifo(data_ptr, data_len);
            self.writeRegister(.Command, command_calc_crc);

            var spins: u16 = 0;
            while (spins < 5000) : (spins += 1) {
                if ((self.readRegister(.DivIrq) & irq_crc) != 0) {
                    return .{
                        self.readRegister(.CRCResultLow),
                        self.readRegister(.CRCResultHigh),
                    };
                }
            }

            return error.Timeout;
        }

        fn transceive(self: *Self, send_ptr: [*]const u8, send_len: usize, tx_last_bits: u8, receive_ptr: [*]u8, receive_len: usize, rx_last_bits: *u8) Error!usize {
            self.writeRegister(.Command, command_idle);
            self.writeRegister(.ComIrq, 0x7F);
            self.writeRegister(.FIFOLevel, flush_fifo);
            self.writeFifo(send_ptr, send_len);
            self.writeRegister(.BitFraming, tx_last_bits & 0x07);
            self.writeRegister(.Command, command_transceive);
            self.setBitMask(.BitFraming, tx_start_send);

            var spins: u16 = 0;
            var completed = false;
            while (spins < 6000) : (spins += 1) {
                const irq = self.readRegister(.ComIrq);
                if ((irq & irq_transceive) != 0) {
                    completed = true;
                    break;
                }
                if ((irq & irq_timer) != 0) {
                    self.clearBitMask(.BitFraming, tx_start_send);
                    return error.Timeout;
                }
            }

            if (!completed) {
                self.clearBitMask(.BitFraming, tx_start_send);
                return error.Timeout;
            }

            self.clearBitMask(.BitFraming, tx_start_send);

            const error_reg = self.readRegister(.Error);
            if ((error_reg & 0x08) != 0) {
                return error.Collision;
            }
            if ((error_reg & 0x13) != 0) {
                return error.Communication;
            }

            const fifo_level = self.readRegister(.FIFOLevel);
            if (fifo_level > receive_len) {
                return error.BufferTooSmall;
            }

            const response_len: usize = fifo_level;

            @setRuntimeSafety(false);
            var index: usize = 0;
            while (index < response_len) : (index += 1) {
                receive_ptr[index] = self.readRegister(.FIFOData);
            }

            rx_last_bits.* = self.readRegister(.Control) & 0x07;
            return response_len;
        }

        fn antennaOn(self: *Self) void {
            if ((self.readRegister(.TxControl) & antenna_enable) != antenna_enable) {
                self.setBitMask(.TxControl, antenna_enable);
            }
        }

        fn writeFifo(self: *Self, data_ptr: [*]const u8, data_len: usize) void {
            var index: usize = 0;
            while (index < data_len) : (index += 1) {
                self.writeRegister(.FIFOData, data_ptr[index]);
            }
        }

        fn writeRegister(self: *Self, register: Register, value: u8) void {
            _ = self;
            const address = (@intFromEnum(register) << 1) & 0x7E;
            select();
            _ = spi.transfer(address);
            _ = spi.transfer(value);
            deselect();
        }

        fn readRegister(self: *Self, register: Register) u8 {
            _ = self;
            const address = ((@intFromEnum(register) << 1) & 0x7E) | 0x80;
            select();
            _ = spi.transfer(address);
            const value = spi.transfer(0x00);
            deselect();
            return value;
        }

        fn setBitMask(self: *Self, register: Register, mask: u8) void {
            self.writeRegister(register, self.readRegister(register) | mask);
        }

        fn clearBitMask(self: *Self, register: Register, mask: u8) void {
            self.writeRegister(register, self.readRegister(register) & ~mask);
        }

        fn select() void {
            gpio.write(cs_pin, false);
        }

        fn deselect() void {
            gpio.write(cs_pin, true);
        }
    };
}

fn ensureDistinctPins(comptime cs_pin: gpio.Pin, comptime rst_pin: gpio.Pin) void {
    if (cs_pin == rst_pin) {
        @compileError("MFRC522 CS and RST pins must be different");
    }
}
