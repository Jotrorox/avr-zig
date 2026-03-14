# Examples

Each example is a standalone Zig project that depends on the root `avr_zig` package through a local path dependency.

All example builds accept `-Dboard=uno`, `-Dboard=nano`, or `-Dboard=mega2560`. Examples that expose `upload` also switch the avrdude part and programmer defaults to match the selected board.

Typical usage from an example directory:

```sh
zig build -Dboard=uno
zig build -Dboard=nano
zig build -Dboard=mega2560
zig build -Dboard=nano upload -Dtty=/dev/ttyUSB0
zig build -Dboard=nano upload -Dtty=/dev/ttyUSB0 -Dupload_profile=nano_old_bootloader
zig build -Dboard=mega2560 upload -Dtty=/dev/ttyACM0
```

Serial-monitor examples keep using `monitor` at `115200` baud. `avr.hal.uart` is still `UART0`, so the examples print on `D0/D1` for all supported boards.

The classic Nano target is the 16 MHz ATmega328P board. It reuses the Uno-compatible digital pin layout, adds analog-only `A6/A7`, and may show up on Linux as `/dev/ttyUSB*`, so `-Dtty=...` is often needed for uploads.

The PWM examples keep using Uno-friendly pins on the Uno and classic Nano, and switch to `D44/D45/D46` on the Mega 2560 so the Timer5 PWM outputs are exercised by default.

Available examples:

- `analog-input`
- `blink`
- `button`
- `custom-hooks`
- `ds1302`
- `dht11`
- `hc-sr04`
- `i2c-scan`
- `lcd-1602-i2c`
- `mfrc522`
- `pwm-fade`
- `pwm-rgb`
- `servo`
- `ssd1306-demo`
- `uart`
