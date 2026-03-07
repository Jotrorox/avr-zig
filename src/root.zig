pub const mcu = struct {
    pub const atmega328p = @import("mcu/atmega328p.zig");
};

pub const board = struct {
    pub const uno = @import("board/uno.zig");
};

pub const hal = struct {
    pub const adc = @import("hal/adc.zig");
    pub const gpio = @import("hal/gpio.zig");
    pub const i2c = @import("hal/i2c.zig");
    pub const pwm = @import("hal/pwm.zig");
    pub const spi = @import("hal/spi.zig");
    pub const time = @import("hal/time.zig");
    pub const uart = @import("hal/uart.zig");
};

pub const drivers = struct {
    pub const actuator = struct {
        pub const servo = @import("drivers/actuator/servo.zig");
    };

    pub const display = struct {
        pub const hd44780_i2c = @import("drivers/display/hd44780_i2c.zig");
        pub const ssd1306 = @import("drivers/display/ssd1306.zig");
    };

    pub const sensor = struct {
        pub const dht11 = @import("drivers/sensor/dht11.zig");
        pub const ds1302 = @import("drivers/sensor/ds1302.zig");
        pub const hc_sr04 = @import("drivers/sensor/hc_sr04.zig");
    };

    pub const rfid = struct {
        pub const mfrc522 = @import("drivers/rfid/mfrc522.zig");
    };
};

pub const runtime = struct {
    pub const Entry = @import("runtime/entry.zig").Entry;
};

pub const adc = hal.adc;
pub const gpio = hal.gpio;
pub const i2c = hal.i2c;
pub const pwm = hal.pwm;
pub const spi = hal.spi;
pub const time = hal.time;
pub const uart = hal.uart;
pub const uno = board.uno;
