---
title: Digital I/O
description: Read buttons and control LEDs with GPIO pins.
sidebar:
  order: 2
---

This guide covers digital input and output -- reading a push button and driving an LED. You'll also learn how to debounce a button and send debug messages over the serial port.

## What you'll need

- A working AVR-Zig project (see [Your First Project](/guides/basic/))
- A push button (momentary tactile switch)
- An LED (any color) and a 220-330 ohm resistor
- A breadboard and jumper wires

## What you'll learn

- Configuring GPIO pins as inputs and outputs
- Using internal pull-up resistors
- Reading a button and controlling an LED
- Debouncing noisy button signals
- Printing debug messages over UART

## Wiring

```
Arduino          Button          LED circuit
-------          ------          -----------
D2  ──────────── one leg
GND ──────────── other leg

D7  ──────────── 220Ω resistor ──── LED anode (+, long leg)
GND ──────────────────────────────── LED cathode (-, short leg)
```

The button connects between **D2** and **GND** with no external resistor -- we'll enable the chip's internal pull-up in software. The LED connects through a current-limiting resistor to **D7**.

:::note[Why no resistor on the button?]
AVR chips have built-in pull-up resistors on every digital pin. When enabled, the pull-up holds the pin at a high (true) level. Pressing the button shorts the pin to GND, pulling it low (false). This means `gpio.read()` returns `true` when the button is **pressed** and connected to GND.

Wait -- that seems backwards. It is! The pull-up holds the pin high when the button is *not* pressed, so the pin reads `false` at rest and `true` when grounded. We invert the logic in code so "pressed" means what you'd expect. The internal pull-up saves you an external resistor and simplifies wiring.
:::

## GPIO output -- driving an LED

Start with the simplest case: turn an LED on and off.

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const time = avr.time;

pub fn main() void {
    gpio.init(.D7, .out); // Configure D7 as output

    while (true) {
        gpio.write(.D7, true);  // LED on
        time.sleep(1000);
        gpio.write(.D7, false); // LED off
        time.sleep(1000);
    }
}
```

`gpio.write(pin, true)` drives the pin high (LED on). `gpio.write(pin, false)` drives it low (LED off). You can also use `gpio.toggle(pin)` to flip the current state, which is what the blink example does.

The `.D7` and `.out` values are Zig **enums**. An enum is a named set of values -- think of it as a label that the compiler checks for you. If you type `.D99` by mistake, the build fails immediately instead of silently doing the wrong thing at runtime.

## GPIO input -- reading a button

Now read the button on D2. The internal pull-up holds the pin high when the button is open, and pressing the button connects it to GND:

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const time = avr.time;

pub fn main() void {
    gpio.init(.D2, .in);        // Configure D2 as input
    gpio.setPullup(.D2, true);  // Enable internal pull-up resistor
    gpio.init(.D7, .out);       // LED on D7

    while (true) {
        const pressed = !gpio.read(.D2); // Low = pressed (pull-up inverts)
        gpio.write(.D7, pressed);        // Mirror button state to LED
        time.sleep(10);
    }
}
```

`gpio.read(.D2)` returns a `bool` -- `true` if the pin voltage is high, `false` if low. Since the pull-up holds the pin high at rest, we invert with `!` so `pressed` is `true` when the button is actually held down.

## Debouncing

Mechanical buttons don't make clean contact. When you press one, the metal contacts bounce for a few milliseconds, producing rapid on-off-on-off noise. If you read the pin during that bounce, your code sees multiple presses from a single push.

The fix is **debouncing**: when you detect a change, wait a short time, then read again. If the value is still different, it's a real press.

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const time = avr.time;

pub fn main() void {
    gpio.init(.D2, .in);
    gpio.setPullup(.D2, true);
    gpio.init(.D7, .out);

    var pressed = !gpio.read(.D2);
    gpio.write(.D7, pressed);

    while (true) {
        const sample = !gpio.read(.D2);

        if (sample != pressed) {
            time.sleep(20); // Wait 20ms for bouncing to settle

            const confirmed = !gpio.read(.D2);
            if (confirmed != pressed) {
                pressed = confirmed;
                gpio.write(.D7, pressed);
            }
        }

        time.sleep(10);
    }
}
```

The 20 ms delay is enough for most tactile switches. The outer `time.sleep(10)` keeps the main loop from spinning as fast as the CPU can go, which saves power.

:::tip[Zig concept: `var` vs `const`]
In Zig, `const` declares a value that never changes, while `var` declares one that can be reassigned. The compiler enforces this -- if you declare something `const` and try to modify it later, the build fails. Use `const` by default and only reach for `var` when you genuinely need to change the value.
:::

## Adding serial output

Printing debug messages over UART is invaluable for embedded development. Add serial output to see when the button state changes:

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const time = avr.time;
const uart = avr.uart;

const button_pin: gpio.Pin = .D2;
const led_pin: gpio.Pin = .D7;

pub fn main() void {
    uart.init(115200);
    gpio.init(button_pin, .in);
    gpio.setPullup(button_pin, true);
    gpio.init(led_pin, .out);

    var pressed = !gpio.read(button_pin);
    gpio.write(led_pin, pressed);
    reportState(pressed);

    while (true) {
        const sample = !gpio.read(button_pin);

        if (sample != pressed) {
            time.sleep(20);

            const confirmed = !gpio.read(button_pin);
            if (confirmed != pressed) {
                pressed = confirmed;
                gpio.write(led_pin, pressed);
                reportState(pressed);
            }
        }

        time.sleep(10);
    }
}

fn reportState(pressed: bool) void {
    uart.write("button=");
    uart.write(if (pressed) "pressed" else "released");
    uart.write("\r\n");
}
```

A few things to notice:

- **`uart.init(115200)`** sets up the serial port at 115200 baud. This must be called once before any `uart.write()` calls. Currently, 115200 is the only supported baud rate.
- **`uart.write("text")`** sends a string. **`uart.write_ch(byte)`** sends a single byte.
- **`\r\n`** is a carriage-return + newline. Serial terminals expect both characters for proper line breaks.
- We extracted the pin names into **named constants** (`button_pin`, `led_pin`) at the top of the file. The type annotation `gpio.Pin` tells both the compiler and the reader what these values are. This is a good habit -- when your program uses many pins, named constants are much clearer than scattered `.D2` and `.D7` literals.

To see the output, flash the firmware and open the serial monitor:

```sh
zig build upload -Dboard=uno -Dtty=/dev/ttyACM0
zig build monitor -Dboard=uno -Dtty=/dev/ttyACM0
```

## GPIO API summary

| Function | Description |
|---|---|
| `gpio.init(pin, .out)` | Configure pin as output |
| `gpio.init(pin, .in)` | Configure pin as input |
| `gpio.write(pin, true/false)` | Drive pin high or low |
| `gpio.read(pin)` | Read pin level (returns `bool`) |
| `gpio.toggle(pin)` | Flip current output state |
| `gpio.setPullup(pin, true/false)` | Enable/disable internal pull-up resistor |

All pin arguments are **comptime** -- they must be known at compile time (like `.D2` or a `const`). This lets the compiler resolve the exact hardware registers and bit masks at build time, producing tight, efficient machine code with no runtime overhead.

## Next steps

You can now read digital inputs and control outputs. The [Analog & PWM](/guides/analog-and-pwm/) guide shows you how to read analog sensors with the ADC and control LED brightness with pulse-width modulation.
