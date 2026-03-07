# avr_zig

`avr_zig` is a Zig library for bare-metal Arduino Uno projects on the ATmega328P.

The package is organized by layer:

- `src/mcu` contains MCU register definitions.
- `src/board` contains board-specific configuration such as the Uno clock.
- `src/hal` contains low-level peripheral access.
- `src/drivers` contains higher-level device drivers.
- `src/runtime` contains startup support used by applications and examples.

The root `build.zig` builds the library archive only. Upload, serial monitor, and objdump steps live in each example's `build.zig` so the examples double as standalone reference projects.

## Package usage

Add this repository as a dependency, import `avr_zig`, and build your executable around `avr.runtime.Entry(App)` where `App` provides `main()` and optional interrupt handlers.

```zig
const std = @import("std");
const avr = @import("avr_zig");
const time = avr.hal.time;
const Runtime = avr.runtime.Entry(App);

pub const App = struct {
    pub const interrupts = struct {
        pub fn TIMER0_COMPA() void {
            time.handleTimer0CompareA();
        }
    };

    pub fn main() void {
        // Application code here.
    }
};

export fn _unhandled_vector() void {
    Runtime.unhandledVector();
}

pub export fn _start() noreturn {
    Runtime.start();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    Runtime.panic(msg, error_return_trace, return_address);
}
```

See the example projects in `examples/` for complete build scripts, linker setup, and flashing commands.