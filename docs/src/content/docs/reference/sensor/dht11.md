---
title: DHT11
description: Read temperature and humidity from a DHT11 sensor using a single GPIO pin.
sidebar:
  order: 1
---

The DHT11 driver reads temperature and humidity from a DHT11 sensor using a single-wire protocol on any digital pin.

```zig
const avr = @import("avr_zig");
const dht11 = avr.drivers.sensor.dht11;
```

## Types

### `Error`

```zig
pub const Error = error{
    Timeout,
    Checksum,
};
```

| Variant | Meaning |
|---|---|
| `Timeout` | The sensor did not respond within the expected time window |
| `Checksum` | The received data failed the checksum verification |

### `Reading`

```zig
pub const Reading = struct {
    humidity: u8,
    humidity_decimal: u8,
    temperature: u8,
    temperature_decimal: u8,
};
```

Holds the result of a successful sensor read.

| Field | Type | Description |
|---|---|---|
| `humidity` | `u8` | Integer part of relative humidity (percent) |
| `humidity_decimal` | `u8` | Decimal part of relative humidity |
| `temperature` | `u8` | Integer part of temperature (Celsius) |
| `temperature_decimal` | `u8` | Decimal part of temperature |

:::note
The DHT11 reports humidity in the range 20--90 % RH and temperature in the range 0--50 °C. The decimal fields are typically zero on genuine DHT11 sensors but are included for protocol completeness.
:::

## Functions

### `read`

```zig
pub fn read(comptime pin: gpio.Pin) Error!Reading
```

Sends the start signal, waits for the sensor response, and reads 40 bits of data (two bytes humidity, two bytes temperature, one byte checksum). Returns a `Reading` on success.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The digital pin connected to the sensor data line (comptime) |

**Returns:** `Error!Reading` -- the sensor reading, or `Timeout` / `Checksum` on failure.

**Behavior:**

1. Pulls the pin low for ~20 ms to issue the start signal, then releases it
2. Waits for the sensor's low-high-low response sequence
3. Reads 40 bits (5 bytes) using pulse-width encoding
4. Verifies the checksum (sum of the first four bytes must equal the fifth)
5. Returns the humidity and temperature fields

:::caution
The DHT11 requires a minimum 1-second interval between reads. Calling `read` more frequently may produce timeouts. The function temporarily reconfigures the pin between output and input mode during the transaction.
:::

## Example

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const uart = avr.uart;
const time = avr.time;
const dht11 = avr.drivers.sensor.dht11;

pub fn main() void {
    uart.init(115200);
    time.init();

    while (true) {
        if (dht11.read(.D4)) |reading| {
            uart.write(reading.temperature);
            uart.write(".");
            writeTwoDigits(reading.temperature_decimal);
            uart.write(" C\r\n");
        } else |_| {
            uart.write("DHT11 read failed\r\n");
        }

        time.sleep(2000);
    }
}

fn writeTwoDigits(value: u8) void {
    uart.write_ch('0' + value / 10);
    uart.write_ch('0' + value % 10);
}
```
