const builtin = @import("builtin");
const std = @import("std");
const avr = @import("avr_zig");

const time = avr.time;
const uart = avr.uart;
const mfrc522 = avr.drivers.rfid.mfrc522;

const Reader = mfrc522.Device(.D10, .D9);
const is_mega2560 = std.mem.eql(u8, builtin.target.cpu.model.name, "atmega2560");
const board_name = if (is_mega2560) "Mega 2560" else "Uno";
const spi_pin_text = if (is_mega2560)
    "CS=D10 RST=D9 MOSI=D51 MISO=D50 SCK=D52\r\n"
else
    "CS=D10 RST=D9 MOSI=D11 MISO=D12 SCK=D13\r\n";

pub fn main() void {
    uart.init(115200);

    var reader = Reader{};
    reader.init();

    uart.write("MFRC522 example on ");
    uart.write(board_name);
    uart.write("\r\n");
    uart.write(spi_pin_text);
    uart.write("Reader version: 0x");
    writeHex(reader.version());
    uart.write("\r\nTap a card to print its UID\r\n");

    var last_uid = [_]u8{ 0, 0, 0, 0 };
    var have_last_uid = false;
    var missing_reads: u8 = 0;

    while (true) {
        const uid = reader.readUid() catch |err| switch (err) {
            error.NoCard => {
                if (have_last_uid) {
                    missing_reads +%= 1;
                    if (missing_reads >= 4) {
                        have_last_uid = false;
                        uart.write("Card removed\r\n");
                    }
                }
                time.sleep(120);
                continue;
            },
            else => {
                uart.write("RFID error: ");
                uart.write(@errorName(err));
                uart.write("\r\n");
                time.sleep(500);
                continue;
            },
        };

        missing_reads = 0;
        if (!have_last_uid or !sameUid(last_uid, uid.bytes)) {
            have_last_uid = true;
            copyUid(&last_uid, uid.bytes);
            writeUid(uid);
        }

        reader.haltA();
        time.sleep(250);
    }
}

fn sameUid(current: [4]u8, next: [4]u8) bool {
    return current[0] == next[0] and
        current[1] == next[1] and
        current[2] == next[2] and
        current[3] == next[3];
}

fn copyUid(destination: *[4]u8, source: [4]u8) void {
    destination[0] = source[0];
    destination[1] = source[1];
    destination[2] = source[2];
    destination[3] = source[3];
}

fn writeUid(uid: mfrc522.Uid) void {
    uart.write("UID=");

    const uid_ptr: [*]const u8 = @ptrCast(&uid.bytes);
    const uid_len: usize = if (uid.len < 4) uid.len else 4;

    var index: usize = 0;
    while (index < uid_len) : (index += 1) {
        if (index != 0) {
            uart.write(":");
        }
        writeHex(uid_ptr[index]);
    }

    uart.write(" SAK=0x");
    writeHex(uid.sak);
    uart.write("\r\n");
}

fn writeHex(value: u8) void {
    uart.write_ch(nibbleToHex((value >> 4) & 0x0F));
    uart.write_ch(nibbleToHex(value & 0x0F));
}

fn nibbleToHex(value: u8) u8 {
    return if (value < 10) '0' + value else 'A' + (value - 10);
}
