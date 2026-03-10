# avr_zig

`avr_zig` is a Zig library for bare-metal Arduino Uno projects on the ATmega328P.

The package is organized by layer:

- `src/mcu` contains MCU register definitions.
- `src/board` contains board-specific configuration such as the Uno clock.
- `src/hal` contains low-level peripheral access such as GPIO, ADC, I2C, PWM, SPI, time, and UART.
- `src/drivers` contains higher-level device drivers such as the SSD1306 display driver, a lightweight DHT11 sensor driver and more.
- `src/runtime` contains startup support used by applications and examples.

The root `build.zig` builds the library archive only. Upload, serial monitor, and objdump steps live in each example's `build.zig` so the examples double as standalone reference projects.

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

Input handling is split between `avr.hal.gpio` for digital pins and `avr.hal.adc` for blocking 10-bit reads on A0-A5. The repository examples include digital button input, analog input sampling, DHT11 sensor polling, MFRC522 RFID UID reads over SPI, and more.
