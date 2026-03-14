# Examples

Each example is a standalone Zig project that depends on the root `avr_zig` package through a local path dependency.

All example builds accept `-Dboard=uno` or `-Dboard=mega2560`. Examples that expose `upload` also switch the avrdude part and programmer defaults to match the selected board.

Typical usage from an example directory:

```sh
zig build -Dboard=uno
zig build -Dboard=mega2560
zig build -Dboard=mega2560 upload -Dtty=/dev/ttyACM0
```

Serial-monitor examples keep using `monitor` at `115200` baud. `avr.hal.uart` is still `UART0`, so the examples print on `D0/D1` for both supported boards.

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
