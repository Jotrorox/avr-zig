---
title: Sensors
description: Read temperature, humidity, and distance from common hobby sensors.
sidebar:
  order: 6
---

This guide shows you how to read two popular Arduino sensors with AVR-Zig: the **DHT11** for temperature and humidity, and the **HC-SR04** for ultrasonic distance measurement. Along the way, you'll learn how Zig handles errors in embedded code.

## DHT11 -- temperature and humidity

The DHT11 is a basic digital sensor that measures temperature (0-50 C) and humidity (20-80%). It uses a custom single-wire protocol -- AVR-Zig's driver handles all the timing-critical bit-banging for you.

### What you'll need

- A DHT11 sensor module (the 3-pin breakout version is easiest)
- A 10K pull-up resistor (some modules have this built in -- check yours)
- A breadboard and jumper wires

### Wiring

```
Arduino             DHT11 module
-------             ------------
5V  ──────────────── VCC (pin 1)
D4  ──────┬──────── DATA (pin 2)
          │
         10K resistor (pull-up to 5V)
          │
5V  ──────┘
GND ──────────────── GND (pin 3 or 4)
```

The data pin needs a pull-up resistor to 5V. Many DHT11 breakout boards already include one -- if yours has three pins and a small resistor visible on the PCB, you can skip the external one.

:::tip
If you're using the raw 4-pin DHT11 component (not a breakout board), pin 3 is unused. Connect pin 1 to 5V, pin 2 to your data pin with a 10K pull-up, and pin 4 to GND.
:::

### Reading temperature and humidity

```zig
const avr = @import("avr_zig");
const dht11 = avr.drivers.sensor.dht11;
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);
    uart.write("DHT11 sensor on D4\r\n");

    while (true) {
        const reading = dht11.read(.D4) catch |err| {
            uart.write("read failed: ");
            uart.write(@errorName(err));
            uart.write("\r\n");
            time.sleep(2000);
            continue;
        };

        uart.write("humidity=");
        uart.write(reading.humidity);
        uart.write(".");
        writeTwoDigits(reading.humidity_decimal);
        uart.write("% temperature=");
        uart.write(reading.temperature);
        uart.write(".");
        writeTwoDigits(reading.temperature_decimal);
        uart.write("C\r\n");

        time.sleep(2000);
    }
}
```

Let's look at the important parts:

**`dht11.read(.D4)`** triggers a full read cycle: the driver sends a start signal, waits for the sensor's response, reads 40 bits of data, and verifies the checksum. This takes a few milliseconds.

**The `catch` block** is the key pattern here. `dht11.read()` returns an **error union** -- either a valid `Reading` or an error. In Zig, you must handle errors explicitly; there are no hidden exceptions.

:::note[Zig concept: error unions and `catch`]
Many functions in AVR-Zig return an **error union**, written as `Error!T`. This means the function returns either a value of type `T` or an error from the `Error` set.

```zig
const reading = dht11.read(.D4) catch |err| {
    // Handle the error
    uart.write(@errorName(err));
    continue; // Skip to the next loop iteration
};
// If we get here, `reading` is a valid Reading struct
```

The `catch |err|` block runs when the function returns an error. `@errorName(err)` converts the error value to a human-readable string like `"Timeout"` or `"Checksum"`. The `continue` statement skips back to the top of the `while` loop.

If the function succeeds, the `catch` block is skipped entirely and `reading` holds the result.
:::

**The `Reading` struct** has four fields:

| Field | Type | Description |
|---|---|---|
| `humidity` | `u8` | Integer part of humidity (e.g., 45) |
| `humidity_decimal` | `u8` | Decimal part of humidity (e.g., 30 for .30) |
| `temperature` | `u8` | Integer part of temperature (e.g., 23) |
| `temperature_decimal` | `u8` | Decimal part of temperature (e.g., 50 for .50) |

The DHT11 transmits integer and decimal parts separately, so the driver returns them as-is. `uart.write()` prints the integer parts directly, and a small helper keeps the decimal part zero-padded.

**Possible errors:**

| Error | Meaning |
|---|---|
| `Timeout` | The sensor didn't respond in time. Check wiring. |
| `Checksum` | Data was received but corrupted. Usually a wiring or noise issue. |

**The 2-second delay** is important -- the DHT11 needs at least 1 second between readings. Polling faster will produce errors.

### Zero-padded decimal helper

The complete example needs one helper to keep the decimal part at exactly two digits:

```zig
fn writeTwoDigits(value: u8) void {
    uart.write_ch('0' + value / 10);
    uart.write_ch('0' + value % 10);
}
```

`uart.write()` already handles the integer part. `writeTwoDigits` only handles the fixed-width decimal field, so a decimal part of `5` still prints as `05`.

## HC-SR04 -- ultrasonic distance

The HC-SR04 measures distance by sending an ultrasonic pulse and timing how long the echo takes to return. It's accurate from about 2 cm to 400 cm.

### What you'll need

- An HC-SR04 ultrasonic sensor module
- A breadboard and jumper wires

### Wiring

```
Arduino             HC-SR04
-------             -------
5V  ──────────────── VCC
D7  ──────────────── TRIG
D6  ──────────────── ECHO
GND ──────────────── GND
```

The trigger pin sends the ultrasonic pulse. The echo pin goes high for the duration of the return trip. Both are 5V-compatible, so no level shifting is needed.

### Measuring distance

```zig
const avr = @import("avr_zig");
const hc_sr04 = avr.drivers.sensor.hc_sr04;
const time = avr.time;
const uart = avr.uart;

const echo_pin: avr.gpio.Pin = .D6;
const trig_pin: avr.gpio.Pin = .D7;

pub fn main() void {
    uart.init(115200);
    hc_sr04.init(echo_pin, trig_pin);
    uart.write("HC-SR04 distance sensor\r\n");

    while (true) {
        const reading = hc_sr04.read(echo_pin, trig_pin) catch |err| {
            uart.write("read failed: ");
            uart.write(@errorName(err));
            uart.write("\r\n");
            time.sleep(250);
            continue;
        };

        uart.write("distance=");
        uart.write(reading.distance_cm);
        uart.write("cm\r\n");

        time.sleep(250);
    }
}
```

The pattern is similar to the DHT11:

1. **`hc_sr04.init(echo_pin, trig_pin)`** configures the GPIO pins (trigger as output, echo as input).
2. **`hc_sr04.read(echo_pin, trig_pin)`** triggers a measurement and returns a `Reading` with `distance_cm` and `pulse_width_us`, or an error.
3. **`uart.write(reading.distance_cm)`** formats the `u16` distance directly, so no decimal helper is needed.
4. **`catch`** handles errors the same way as the DHT11 example.

**The `Reading` struct:**

| Field | Type | Description |
|---|---|---|
| `distance_cm` | `u16` | Calculated distance in centimeters |
| `pulse_width_us` | `u16` | Raw echo pulse width in microseconds |

**Possible errors:**

| Error | Meaning |
|---|---|
| `EchoStartTimeout` | Echo pin didn't go high after trigger. Check wiring. |
| `EchoEndTimeout` | Echo pin stayed high too long (object too far or no object). |
| `Timer1Unavailable` | Timer1 is in use by the servo driver. |

:::caution[Timer1 conflict]
The HC-SR04 driver uses Timer1 to time the echo pulse. If you're also using the servo driver (which also uses Timer1), `read()` will return `Timer1Unavailable`. You can't use both simultaneously -- take your distance measurement, then initialize the servo, or vice versa.
:::

The 250 ms delay between readings gives the ultrasonic pulse time to dissipate. Faster polling can cause echoes from previous measurements to interfere.

## Error handling patterns

Both sensor drivers follow the same Zig error pattern. Here's a summary of the approaches you can use:

**`catch` with continue** -- skip the failed iteration and try again (used in both examples above):

```zig
const reading = sensor.read(.D4) catch |err| {
    // Log the error and try again next loop
    uart.write(@errorName(err));
    continue;
};
```

**`catch` with a default value** -- use a fallback when the read fails:

```zig
const reading = sensor.read(.D4) catch Reading{
    .humidity = 0,
    .humidity_decimal = 0,
    .temperature = 0,
    .temperature_decimal = 0,
};
```

**`try`** -- propagate the error to the caller (only works if the calling function also returns an error union):

```zig
fn readSensor() Error!void {
    const reading = try sensor.read(.D4);
    // Use reading...
}
```

In `main()`, which returns `void`, you can't use `try` -- you must handle errors with `catch`. This is a deliberate Zig design choice: errors are never silently ignored.

## Other supported sensors

AVR-Zig includes drivers for several other sensors. Each has a corresponding example in the `examples/` directory:

| Sensor | Module path | What it does |
|---|---|---|
| DS1302 | `avr.drivers.sensor.ds1302` | Real-time clock (read/write date and time) |
| KY-038 | `avr.drivers.sensor.ky_038` | Sound level sensor (analog and digital) |
| SW-520D | `avr.drivers.sensor.sw_520d` | Tilt/vibration switch |
| MFRC522 | `avr.drivers.rfid.mfrc522` | RFID card reader over SPI |

Check the corresponding example directories (`examples/ds1302`, `examples/ky-038-analog`, etc.) for complete working code.

## What's next

You've now covered the core of AVR-Zig: GPIO, analog, PWM, serial, displays, and sensors. From here you can:

- Browse all the [examples on GitHub](https://github.com/arcembed/avr-zig/tree/main/examples) for more complete projects
- Combine what you've learned -- display sensor readings on an OLED, trigger a servo based on distance, or log button events over UART
- Look at the `custom-hooks` example to learn how to override the default panic handler and unhandled-interrupt behavior
