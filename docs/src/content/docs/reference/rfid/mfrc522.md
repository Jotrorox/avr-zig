---
title: MFRC522 RFID
description: Read RFID card UIDs with an MFRC522 module over SPI.
sidebar:
  order: 1
---

The MFRC522 driver communicates with an MFRC522 RFID reader/writer module over SPI. It supports card detection and reading 4-byte UIDs (single-size, cascade level 1).

```zig
const avr = @import("avr_zig");
const mfrc522 = avr.drivers.rfid.mfrc522;
```

:::note
The driver calls `avr.spi.init(.f16)` internally during initialization. You do not need to call `spi.init` yourself, but be aware that it sets the SPI clock divider to `/16`.
:::

## Types

### `Error`

```zig
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
```

| Variant | Meaning |
|---|---|
| `NoCard` | No card responded to the REQA command |
| `Timeout` | The reader timed out waiting for a response |
| `Collision` | Multiple cards responded simultaneously |
| `Communication` | A communication error was detected in the error register |
| `BufferTooSmall` | The FIFO response exceeded the expected buffer size |
| `Protocol` | The response length or format was unexpected |
| `Crc` | CRC verification failed on the response |
| `UnsupportedUid` | The card uses a multi-level UID (7 or 10 bytes) which is not supported |

### `Uid`

```zig
pub const Uid = struct {
    bytes: [4]u8,
    len: u8,
    sak: u8,
};
```

| Field | Type | Description |
|---|---|---|
| `bytes` | `[4]u8` | The 4-byte card UID |
| `len` | `u8` | Number of valid UID bytes (always 4 for single-size UIDs) |
| `sak` | `u8` | Select Acknowledge byte indicating the card type |

## `Device`

```zig
pub fn Device(comptime cs_pin: gpio.Pin, comptime rst_pin: gpio.Pin) type
```

Returns an MFRC522 driver type for the given chip-select and reset pins. The SPI data lines (MOSI, MISO, SCK) use the board's hardware SPI pins.

| Parameter | Type | Description |
|---|---|---|
| `cs_pin` | `gpio.Pin` | SPI chip-select pin (active low) (comptime) |
| `rst_pin` | `gpio.Pin` | Hardware reset pin (comptime) |

**Compile constraints:**

- `cs_pin` and `rst_pin` must be different. Using the same pin produces a compile error: `"MFRC522 CS and RST pins must be different"`.

**Hardware SPI pins by board:**

| Board | SS | MOSI | MISO | SCK |
|---|---|---|---|---|
| Uno / Nano | `D10` | `D11` | `D12` | `D13` |
| Mega 2560 | `D53` | `D51` | `D50` | `D52` |

:::tip
The `cs_pin` does not need to be the board's default SS pin -- you can use any digital pin for chip select. However, the hardware SS pin must still be configured as output (the SPI master mode requirement); `spi.init` handles this automatically.
:::

### Methods

#### `init`

```zig
pub fn init(self: *Self) void
```

Initializes the MFRC522 reader:

1. Calls `spi.init(.f16)` to configure hardware SPI with clock divider /16
2. Configures `cs_pin` and `rst_pin` as outputs
3. Performs a hardware reset (RST low for 10 ms, then high, wait 50 ms)
4. Issues a soft reset command and waits 50 ms
5. Configures the timer, CRC, TX/RX modes, and modulation registers
6. Clears collision detection flags
7. Enables the antenna

#### `version`

```zig
pub fn version(self: *Self) u8
```

Reads the chip version register.

**Returns:** `u8` -- typically `0x91` for MFRC522 v1.0 or `0x92` for v2.0. A return value of `0x00` or `0xFF` usually indicates a wiring problem.

#### `isCardPresent`

```zig
pub fn isCardPresent(self: *Self) bool
```

Sends a REQA command and returns whether a card responded.

**Returns:** `bool` -- `true` if a card answered, `false` otherwise (including on any communication error).

#### `requestA`

```zig
pub fn requestA(self: *Self) Error![2]u8
```

Sends a REQA (Request Type A) command. Returns the 2-byte ATQA (Answer To Request) response which encodes information about the card type and UID size.

**Returns:** `Error![2]u8` -- the ATQA bytes, or an error.

#### `readUid`

```zig
pub fn readUid(self: *Self) Error!Uid
```

Reads the full 4-byte UID of a card. Internally sends a REQA followed by an anti-collision and select sequence (cascade level 1).

**Returns:** `Error!Uid` -- the card's UID and SAK byte, or an error.

:::caution
This driver only supports single-size (4-byte) UIDs. Cards with 7-byte or 10-byte UIDs will return `UnsupportedUid` during the select sequence.
:::

#### `haltA`

```zig
pub fn haltA(self: *Self) void
```

Sends a HLTA (Halt Type A) command to put the active card into the HALT state. After halting, the card will not respond to `requestA` until it is removed and re-presented, or a WUPA command is sent.

## Example

```zig
const avr = @import("avr_zig");
const uart = avr.uart;
const time = avr.time;
const mfrc522 = avr.drivers.rfid.mfrc522;

const Reader = mfrc522.Device(.D10, .D9);

pub fn main() void {
    uart.init();
    time.init();

    var reader = Reader{};
    reader.init();

    uart.write("MFRC522 version: 0x");
    uart.writeInt(u8, reader.version());
    uart.write("\r\n");

    while (true) {
        if (reader.isCardPresent()) {
            if (reader.readUid()) |uid| {
                uart.write("UID:");
                for (uid.bytes[0..uid.len]) |byte| {
                    uart.write(" ");
                    uart.writeInt(u8, byte);
                }
                uart.write("\r\n");
                reader.haltA();
            } else |_| {
                uart.write("Read error\r\n");
            }
        }
        time.sleep(250);
    }
}
```
