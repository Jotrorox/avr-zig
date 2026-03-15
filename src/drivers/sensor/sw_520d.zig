const gpio = @import("../../hal/gpio.zig");

pub const State = enum {
    open,
    closed,
};

/// Configures the tilt sensor input pin.
pub fn init(comptime pin: gpio.Pin, enable_pullup: bool) void {
    gpio.init(pin, .in);
    gpio.setPullup(pin, enable_pullup);
}

/// Returns the raw switch state.
pub fn state(comptime pin: gpio.Pin) State {
    return if (gpio.read(pin)) .open else .closed;
}

pub fn isOpen(comptime pin: gpio.Pin) bool {
    return state(pin) == .open;
}

pub fn isClosed(comptime pin: gpio.Pin) bool {
    return state(pin) == .closed;
}
