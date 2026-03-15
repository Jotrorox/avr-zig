> [!IMPORTANT]
> This repository has moved to the **Arc Embed** organization.
> Please use the new canonical location:
> https://github.com/arcembed/avr-zig


# avr_zig

`avr_zig` is a Zig library for bare-metal Arduino projects on AVR microcontrollers.

Supported boards in this repository:

- Arduino Uno on the ATmega328P
- Classic Arduino Nano on the ATmega328P
- Arduino Mega 2560 on the ATmega2560

The package is organized by layer:

- `src/mcu` contains MCU register definitions.
- `src/board` contains board-specific configuration such as board clocks.
- `src/hal` contains low-level peripheral access such as GPIO, ADC, I2C, PWM, SPI, time, and UART.
- `src/drivers` contains higher-level device drivers such as the SSD1306 display driver, a lightweight DHT11 sensor driver and more.
- `src/runtime` contains startup support used by applications and examples.

The root `build.zig` builds the library archive only. Select the target board with `-Dboard=uno`, `-Dboard=nano`, or `-Dboard=mega2560`. Upload, serial monitor, and objdump steps live in each example's `build.zig` so the examples double as standalone reference projects.

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

Input handling is split between `avr.hal.gpio` for digital pins and `avr.hal.adc` for blocking 10-bit reads. The Uno target exposes `A0..A5`; the classic Nano target exposes `A0..A7` with `A6/A7` as analog-only pins; the Mega 2560 target exposes `A0..A15`. The repository examples include digital button input, analog input sampling, DHT11 sensor polling, MFRC522 RFID UID reads over SPI, and more.

## Board Selection

Build the library archive for a specific board with:

```sh
zig build check -Dboard=uno
zig build check -Dboard=nano
zig build check -Dboard=mega2560
```

The public API stays the same across all three targets. `avr.gpio.Pin` and `avr.adc.AnalogPin` are selected from the active compile target, so existing Uno applications keep compiling unchanged while Nano builds gain `A6/A7` analog inputs and Mega builds gain the larger Mega pin set.

Classic Nano support reuses the existing `ATmega328P` runtime and linker script. This target is for the classic 16 MHz Nano only; Nano Every, Nano 33 variants, and ESP32-based Nano boards are out of scope.

## Board Notes

- `avr.hal.uart` remains `UART0` on all supported boards in this first pass.
- Uno and classic Nano `SPI` use `D10..D13`; Mega 2560 `SPI` uses `D50..D53`.
- Uno and classic Nano `I2C` use `A4/A5`; Mega 2560 `I2C` uses `D20/D21`.
- `avr.hal.time` reserves `Timer0`, so Timer0-backed PWM outputs stay unavailable.
- `avr.hal.pwm` currently supports `D3`, `D9`, `D10`, and `D11` on the Uno and classic Nano.
- `avr.hal.pwm` on the Mega 2560 supports `D2`, `D3`, `D5`, `D6`, `D7`, `D8`, `D9`, `D10`, `D11`, `D12`, `D13`, `D44`, `D45`, and `D46`.
- The servo driver stays Timer1-based. The default servo example uses `D9` on the Uno and classic Nano, and `D11` on the Mega 2560.
- Classic Nano `A6` and `A7` are available through `avr.hal.adc` only; they are not part of `avr.gpio.Pin`.
- Example `upload` steps accept `-Dupload_profile=default` or `-Dupload_profile=nano_old_bootloader`. The old-bootloader option is only relevant to classic Nano boards that still use the older 57600 baud bootloader.
