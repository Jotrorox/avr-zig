---
title: Analog & PWM
description: Read analog sensors and control LED brightness with pulse-width modulation.
sidebar:
  order: 3
---

This guide covers two complementary features: reading analog values from sensors with the ADC (analog-to-digital converter), and writing analog-like output with PWM (pulse-width modulation). Together they let you read a potentiometer and smoothly dim an LED.

## What you'll need

- A working AVR-Zig project (see [Your First Project](./basic/))
- A potentiometer (any value from 1K to 100K works)
- An LED and a 220-330 ohm resistor
- A breadboard and jumper wires

## What you'll learn

- How the ADC converts voltage to a number
- Reading analog pins with `adc.read()`
- What PWM is and how it simulates analog output
- Fading an LED with `pwm.init()` and `pwm.write()`
- Combining analog input with PWM output

## Reading analog values

Digital pins only see high or low. Analog pins measure a *voltage* and convert it to a number. The AVR's ADC produces a 10-bit result: **0** for 0V, **1023** for 5V, and proportional values in between.

### Wiring a potentiometer

```
Arduino             Potentiometer
-------             -------------
5V  ──────────────── outer leg 1
A0  ──────────────── middle leg (wiper)
GND ──────────────── outer leg 2
```

Turning the knob sweeps the middle pin from 0V to 5V. The ADC on pin A0 reads that voltage.

### Reading and printing the value

```zig
const avr = @import("avr_zig");
const adc = avr.adc;
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);
    uart.write("Analog read example\r\n");

    while (true) {
        const sample = adc.read(.A0);

        uart.write("A0=0x");
        writeHexWord(sample);
        uart.write("\r\n");

        time.sleep(250);
    }
}
```

`adc.read(.A0)` returns a `u16` between 0 and 1023. The ADC initializes itself automatically on the first call -- you don't need a separate init step.

:::note[What is `u16`?]
Zig uses explicit integer sizes. `u16` means an unsigned 16-bit integer (0 to 65535). The ADC only produces 10-bit values (0 to 1023), but `u16` is the smallest standard type that fits. Other types you'll see in AVR-Zig: `u8` (0 to 255), `u32` (0 to ~4 billion), and `bool` (true/false).
:::

### Formatting numbers for serial output

The UART module sends raw bytes and strings -- it has no built-in number formatting. You need small helper functions to convert numbers to text. Here's the hex formatter used above and a decimal formatter you'll find useful:

```zig
fn writeHexWord(value: u16) void {
    writeHexNibble(@as(u8, @intCast((value >> 12) & 0x0F)));
    writeHexNibble(@as(u8, @intCast((value >> 8) & 0x0F)));
    writeHexNibble(@as(u8, @intCast((value >> 4) & 0x0F)));
    writeHexNibble(@as(u8, @intCast(value & 0x0F)));
}

fn writeHexNibble(value: u8) void {
    const digit = if (value < 10) '0' + value else 'A' + (value - 10);
    uart.write_ch(digit);
}

fn writeDecimal(value: u16) void {
    if (value >= 1000) uart.write_ch('0' + @as(u8, @intCast(value / 1000 % 10)));
    if (value >= 100) uart.write_ch('0' + @as(u8, @intCast(value / 100 % 10)));
    if (value >= 10) uart.write_ch('0' + @as(u8, @intCast(value / 10 % 10)));
    uart.write_ch('0' + @as(u8, @intCast(value % 10)));
}
```

:::tip[Zig concept: `@as` and `@intCast`]
The `@as(u8, ...)` syntax tells Zig you want a `u8` value. `@intCast` converts between integer types -- for example, narrowing a `u16` down to a `u8`. Zig requires these casts to be explicit so you never accidentally lose data. If the value doesn't fit, the program traps at runtime in safe build modes.
:::

## PWM output -- fading an LED

PWM rapidly switches a pin on and off. By varying the ratio of on-time to off-time (the **duty cycle**), you can control the average power delivered to an LED, making it appear to dim smoothly.

AVR-Zig's PWM uses an 8-bit duty cycle: **0** is fully off, **255** is fully on.

### Wiring

```
Arduino             LED circuit
-------             -----------
D9  ──────────────── 220Ω resistor ──── LED anode (+)
GND ──────────────────────────────────── LED cathode (-)
```

Pin D9 is connected to Timer1 on the Uno and Nano, which makes it PWM-capable.

### Fade up and down

```zig
const avr = @import("avr_zig");
const pwm = avr.pwm;
const time = avr.time;

pub fn main() void {
    pwm.init(.D9);

    var duty: u8 = 0;
    var rising = true;

    while (true) {
        pwm.write(.D9, duty);
        time.sleep(4);

        if (rising) {
            if (duty == pwm.max_duty) {
                rising = false;
            } else {
                duty += 1;
            }
        } else {
            if (duty == 0) {
                rising = true;
            } else {
                duty -= 1;
            }
        }
    }
}
```

`pwm.init(.D9)` configures the pin and its underlying hardware timer. `pwm.write(.D9, duty)` sets the duty cycle. The loop ramps the duty from 0 to 255 and back, creating a smooth breathing effect. Each step takes 4 ms, so a full cycle (0 to 255 to 0) takes about 2 seconds.

`pwm.max_duty` is a constant equal to 255 -- use it instead of a magic number.

### Which pins support PWM?

Not every pin can do PWM. It depends on which hardware timer the pin is connected to:

| Board | PWM pins |
|---|---|
| Uno / Nano | D3, D9, D10, D11 |
| Mega 2560 | D2, D3, D5, D6, D7, D8, D9, D10, D11, D12, D13, D44, D45, D46 |

:::caution
D5 and D6 on the Uno/Nano use Timer0, which is reserved by `avr.time` for millisecond timing. Attempting `pwm.init(.D5)` on those boards will produce a compile error.
:::

You can check at compile time whether a pin supports PWM:

```zig
if (pwm.supports(.D9)) {
    pwm.init(.D9);
}
```

## Putting it together -- potentiometer controls LED

This example reads the potentiometer on A0 and maps the 10-bit ADC value (0-1023) down to an 8-bit PWM duty cycle (0-255) to control LED brightness:

```zig
const avr = @import("avr_zig");
const adc = avr.adc;
const pwm = avr.pwm;
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);
    pwm.init(.D9);

    while (true) {
        const sample = adc.read(.A0); // 0..1023
        const duty: u8 = @intCast(sample >> 2); // Shift right by 2 to get 0..255

        pwm.write(.D9, duty);

        uart.write("adc=");
        writeDecimal(sample);
        uart.write(" duty=");
        writeDecimalU8(duty);
        uart.write("\r\n");

        time.sleep(50);
    }
}

fn writeDecimal(value: u16) void {
    if (value >= 1000) uart.write_ch('0' + @as(u8, @intCast(value / 1000 % 10)));
    if (value >= 100) uart.write_ch('0' + @as(u8, @intCast(value / 100 % 10)));
    if (value >= 10) uart.write_ch('0' + @as(u8, @intCast(value / 10 % 10)));
    uart.write_ch('0' + @as(u8, @intCast(value % 10)));
}

fn writeDecimalU8(value: u8) void {
    if (value >= 100) uart.write_ch('0' + value / 100);
    if (value >= 10) uart.write_ch('0' + value / 10 % 10);
    uart.write_ch('0' + value % 10);
}
```

The key line is `@intCast(sample >> 2)` -- shifting right by 2 bits divides by 4, mapping the 0-1023 range down to 0-255. Turn the knob, and the LED brightness follows.

## Board-specific analog pins

Different boards expose different analog pins:

| Board | Analog pins | Notes |
|---|---|---|
| Uno | A0 -- A5 | A4/A5 are shared with I2C |
| Nano | A0 -- A7 | A6/A7 are **analog-only** (no digital GPIO) |
| Mega 2560 | A0 -- A15 | A4/A5 are general-purpose (I2C uses D20/D21) |

If your code needs to work across boards, you can use a comptime check:

```zig
const avr = @import("avr_zig");
const analog_pin: avr.adc.AnalogPin = if (avr.current_board == .nano) .A7 else .A0;
```

This is evaluated entirely at compile time -- no runtime cost, no `if` branch in the final firmware.

## Next steps

You now know how to read analog sensors and control output intensity. The [Serial Communication](./serial-communication/) guide dives deeper into UART and introduces I2C, which you'll need for displays and many sensors.
