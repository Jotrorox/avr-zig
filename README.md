# avr_zig

`avr_zig` is a Zig library for bare-metal Arduino projects on AVR microcontrollers.

Supported boards in this repository:

- Arduino Uno on the ATmega328P
- Arduino Mega 2560 on the ATmega2560

The package is organized by layer:

- `src/mcu` contains MCU register definitions.
- `src/board` contains board-specific configuration such as board clocks.
- `src/hal` contains low-level peripheral access such as GPIO, ADC, I2C, PWM, SPI, time, and UART.
- `src/drivers` contains higher-level device drivers such as the SSD1306 display driver, a lightweight DHT11 sensor driver and more.
- `src/runtime` contains startup support used by applications and examples.

The root `build.zig` builds the library archive only. Select the target board with `-Dboard=uno` or `-Dboard=mega2560`. Upload, serial monitor, and objdump steps live in each example's `build.zig` so the examples double as standalone reference projects.

## Package usage

Add this repository as a dependency, make `avr_zig`'s runtime bootstrap the executable root module in your `build.zig`, and keep your application module focused on `main()` plus optional interrupt handlers.


```zig
const avr = @import("avr_zig");

pub fn main() void {
    // Application code here.
}
```

Timer-backed helpers such as `avr.hal.time.sleep()` automatically provide their default interrupt handlers. Advanced applications can still override `pub const interrupts.TIMER0_COMPA()` explicitly when they need custom Timer0 behavior.

See the example projects in `examples/` for complete build scripts, linker setup, and flashing commands.

Input handling is split between `avr.hal.gpio` for digital pins and `avr.hal.adc` for blocking 10-bit reads. The Uno target exposes `A0..A5`; the Mega 2560 target exposes `A0..A15`. The repository examples include digital button input, analog input sampling, DHT11 sensor polling, MFRC522 RFID UID reads over SPI, and more.

## Board Selection

Build the library archive for a specific board with:

```sh
zig build check -Dboard=uno
zig build check -Dboard=mega2560
```

The public API stays the same across both targets. `avr.gpio.Pin` and `avr.adc.AnalogPin` are selected from the active compile target, so existing Uno applications keep compiling unchanged while Mega builds gain the larger Mega pin set.

## Board Notes

- `avr.hal.uart` remains `UART0` on both boards in this first pass.
- Uno `SPI` uses `D10..D13`; Mega 2560 `SPI` uses `D50..D53`.
- Uno `I2C` uses `A4/A5`; Mega 2560 `I2C` uses `D20/D21`.
- `avr.hal.time` reserves `Timer0`, so Timer0-backed PWM outputs stay unavailable.
- `avr.hal.pwm` currently supports `D3`, `D9`, `D10`, and `D11` on the Uno, and `D9`, `D10`, `D11`, and `D12` on the Mega 2560.
- The servo driver stays Timer1-based. The default servo example uses `D9` on the Uno and `D11` on the Mega 2560.
