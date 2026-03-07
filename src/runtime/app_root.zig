const std = @import("std");
const avr = @import("avr_zig");
const App = @import("app");

const Runtime = avr.runtime.Entry(App);

export fn _unhandled_vector() void {
    if (@hasDecl(App, "unhandledVector")) {
        App.unhandledVector();
    } else {
        Runtime.unhandledVector();
    }
}

pub export fn _start() noreturn {
    Runtime.start();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    if (@hasDecl(App, "panic")) {
        App.panic(msg, error_return_trace, return_address);
    } else {
        Runtime.panic(msg, error_return_trace, return_address);
    }
}
