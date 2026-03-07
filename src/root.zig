pub const mcu = struct {
    pub const atmega328p = @import("mcu/atmega328p.zig");
};

pub const board = struct {
    pub const uno = @import("board/uno.zig");
};

pub const hal = struct {
    pub const gpio = @import("hal/gpio.zig");
    pub const i2c = @import("hal/i2c.zig");
    pub const pwm = @import("hal/pwm.zig");
    pub const time = @import("hal/time.zig");
    pub const uart = @import("hal/uart.zig");
};

pub const drivers = struct {
    pub const display = struct {
        pub const ssd1306 = @import("drivers/display/ssd1306.zig");
    };
};

pub const runtime = struct {
    pub const Entry = @import("runtime/entry.zig").Entry;
};

pub const gpio = hal.gpio;
pub const i2c = hal.i2c;
pub const pwm = hal.pwm;
pub const time = hal.time;
pub const uart = hal.uart;
pub const uno = board.uno;
pub const ssd1306 = drivers.display.ssd1306;
