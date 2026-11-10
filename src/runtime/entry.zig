const std = @import("std");
const builtin = std.builtin;
const platform = @import("../platform/current.zig");
const time = @import("../hal/time.zig");
const uart = @import("../hal/uart.zig");

fn validateInterruptNamespace(comptime Namespace: type, comptime namespace_name: []const u8) void {
    if (@hasDecl(Namespace, "RESET")) {
        @compileError("Not allowed to overload the reset vector in '" ++ namespace_name ++ "'");
    }

    const info = @typeInfo(Namespace);
    switch (info) {
        .@"struct" => |strct| {
            inline for (strct.field_names) |decl| {
                if (!@hasField(platform.VectorTable, decl)) {
                    var msg: []const u8 = "There is no such interrupt as '" ++ decl ++ "'. ISRs in '" ++ namespace_name ++ "' must be one of:\n";
                    for (@typeInfo(platform.VectorTable).@"struct".field_names) |field_name| {
                        if (!std.mem.eql(u8, "RESET", field_name)) {
                            msg = msg ++ "    " ++ field_name ++ "\n";
                        }
                    }
                    @compileError(msg);
                }
            }
        },
        else => unreachable,
    }
}

fn exportInterruptHandler(comptime Namespace: type, comptime name: []const u8) void {
    const handler = @field(Namespace, name);
    // const info =@typeInfo(Namespace);

    const calling_convention = switch (@typeInfo(@TypeOf(handler))) {
        .@"fn" => |info| info.attrs.@"callconv",
        else => @compileError("Declarations in the interrupt namespace must all be functions. '" ++ name ++ "' is not a function"),
    };

    const exported_fn = switch (calling_convention) {
        .auto => struct {
            fn wrapper() callconv(.avr_interrupt) void {
                @call(.always_inline, handler, .{});
            }
        }.wrapper,
        else => @compileError("Leave interrupt handlers with an unspecified calling convention"),
    };

    const options: builtin.ExportOptions = .{ .name = name, .linkage = .strong };
    @export(&exported_fn, options);
}

/// Returns the runtime entry type.
pub fn Entry(comptime App: type) type {
    comptime {
        if (!@hasDecl(App, "main")) {
            @compileError("Applications using avr_zig.runtime.Entry must provide App.main()");
        }
    }

    return struct {
        comptime {
            std.debug.assert(std.mem.eql(u8, "RESET", @typeInfo(platform.VectorTable).@"struct".field_names[0]));

            var asm_str: []const u8 = ".section .vectors\njmp _start\n";
            const has_interrupts = @hasDecl(App, "interrupts");
            const runtime_interrupts = time.runtime_interrupts;

            validateInterruptNamespace(runtime_interrupts, "runtime_interrupts");

            if (has_interrupts) {
                validateInterruptNamespace(App.interrupts, "interrupts");
            }

            const info = @typeInfo(platform.VectorTable);
            switch (info) {
                .@"struct" => |strct| {
                    for (strct.field_names[1..]) |field_name| {
                        const new_instruction = if (has_interrupts) overload: {
                            if (@hasDecl(App.interrupts, field_name)) {
                                exportInterruptHandler(App.interrupts, field_name);
                                break :overload "jmp " ++ field_name;
                            }

                            if (@hasDecl(runtime_interrupts, field_name)) {
                                exportInterruptHandler(runtime_interrupts, field_name);
                                break :overload "jmp " ++ field_name;
                            }

                            break :overload "jmp _unhandled_vector";
                        } else if (@hasDecl(runtime_interrupts, field_name)) runtime_default: {
                            exportInterruptHandler(runtime_interrupts, field_name);
                            break :runtime_default "jmp " ++ field_name;
                        } else "jmp _unhandled_vector";

                        asm_str = asm_str ++ new_instruction ++ "\n";
                    }

                    asm (asm_str);
                },
                else => @compileError("The platform's vector table is not a struct. This is unexpected."),
            }
        }

        /// Handles an unbound interrupt.
        pub fn unhandledVector() void {
            while (true) {}
        }

        /// Starts the application.
        pub fn start() noreturn {
            copy_data_to_ram();
            clear_bss();

            App.main();
            while (true) {}
        }

        fn copy_data_to_ram() void {
            asm volatile (
                \\  ldi r30, lo8(__data_load_start)
                \\  ldi r31, hi8(__data_load_start)
                \\  ldi r26, lo8(__data_start)
                \\  ldi r27, hi8(__data_start)
                \\  ldi r24, lo8(__data_end)
                \\  ldi r25, hi8(__data_end)
                \\  rjmp .L2
                \\
                \\.L1:
                \\  lpm r18, Z+
                \\  st X+, r18
                \\
                \\.L2:
                \\  cp r26, r24
                \\  cpc r27, r25
                \\  brne .L1
            );
        }

        fn clear_bss() void {
            asm volatile (
                \\  ldi r26, lo8(__bss_start)
                \\  ldi r27, hi8(__bss_start)
                \\  ldi r24, lo8(__bss_end)
                \\  ldi r25, hi8(__bss_end)
                \\  ldi r18, 0x00
                \\  rjmp .L4
                \\
                \\.L3:
                \\  st X+, r18
                \\
                \\.L4:
                \\  cp r26, r24
                \\  cpc r27, r25
                \\  brne .L3
            );
        }

        /// Prints a panic message.
        pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace, _: ?usize) noreturn {
            uart.write("PANIC: ");
            uart.write(msg);

            _ = error_return_trace;
            while (true) {}
        }
    };
}
