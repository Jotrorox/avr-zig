---
title: HC-SR04
description: Measure distance with an HC-SR04 ultrasonic sensor using Timer1.
sidebar:
  order: 3
---

The HC-SR04 driver measures distance by sending an ultrasonic trigger pulse and timing the echo response. It uses Timer1 temporarily for microsecond-precision timing.

```zig
const avr = @import("avr_zig");
const hc_sr04 = avr.drivers.sensor.hc_sr04;
```

## Types

### `Error`

```zig
pub const Error = error{
    EchoStartTimeout,
    EchoEndTimeout,
    Timer1Unavailable,
};
```

| Variant | Meaning |
|---|---|
| `EchoStartTimeout` | The echo pin did not go high within the timeout window |
| `EchoEndTimeout` | The echo pin did not return low within the timeout window |
| `Timer1Unavailable` | Timer1 is currently in use by the [servo driver](../actuator/servo/) |

### `Reading`

```zig
pub const Reading = struct {
    pulse_width_us: u16,
    distance_cm: u16,
};
```

| Field | Type | Description |
|---|---|---|
| `pulse_width_us` | `u16` | Round-trip echo time in microseconds |
| `distance_cm` | `u16` | Calculated distance in centimeters |

:::note
The distance calculation uses a fast integer approximation of dividing the pulse width by 58. The practical measurement range of the HC-SR04 is 2--400 cm.
:::

## Functions

### `init`

```zig
pub fn init(comptime echo_pin: gpio.Pin, comptime trig_pin: gpio.Pin) void
```

Configures the trigger pin as output (driven low) and the echo pin as input (no pull-up).

| Parameter | Type | Description |
|---|---|---|
| `echo_pin` | `gpio.Pin` | The pin connected to the sensor's Echo output (comptime) |
| `trig_pin` | `gpio.Pin` | The pin connected to the sensor's Trig input (comptime) |

**Compile constraints:**

- `echo_pin` and `trig_pin` must be different. Using the same pin for both produces a compile error: `"HC-SR04 echo and trig pins must be different"`.

### `read`

```zig
pub fn read(comptime echo_pin: gpio.Pin, comptime trig_pin: gpio.Pin) Error!Reading
```

Performs a single distance measurement. Calls `init` internally, then sends a 10 us trigger pulse and times the echo response using Timer1.

| Parameter | Type | Description |
|---|---|---|
| `echo_pin` | `gpio.Pin` | The pin connected to the sensor's Echo output (comptime) |
| `trig_pin` | `gpio.Pin` | The pin connected to the sensor's Trig input (comptime) |

**Returns:** `Error!Reading` -- the measurement, or an error on timeout or Timer1 conflict.

**Behavior:**

1. Calls `init` to configure the pins
2. Checks if the [servo driver](../actuator/servo/) has Timer1 active -- returns `Timer1Unavailable` if so
3. Saves the current Timer1 register state and configures Timer1 in normal mode with prescaler /8
4. Sends a 10 us trigger pulse on `trig_pin`
5. Waits for `echo_pin` to go high (start of echo) -- returns `EchoStartTimeout` on failure
6. Waits for `echo_pin` to go low (end of echo) -- returns `EchoEndTimeout` on failure
7. Converts the timer tick count to microseconds and distance in centimeters
8. Restores the original Timer1 state before returning

:::caution
Timer1 is shared with the [servo driver](../actuator/servo/). You cannot use both drivers simultaneously. The HC-SR04 driver borrows Timer1 only for the duration of each `read` call and restores its previous configuration afterward.
:::

## Example

```zig
const avr = @import("avr_zig");
const uart = avr.uart;
const time = avr.time;
const hc_sr04 = avr.drivers.sensor.hc_sr04;

pub fn main() void {
    uart.init(115200);
    time.init();

    while (true) {
        if (hc_sr04.read(.D3, .D2)) |reading| {
            uart.write(reading.distance_cm);
            uart.write(" cm\r\n");
        } else |_| {
            uart.write("HC-SR04 read failed\r\n");
        }

        time.sleep(500);
    }
}
```
