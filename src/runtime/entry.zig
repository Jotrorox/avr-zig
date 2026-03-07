const std = @import("std");
const builtin = std.builtin;
const atmega328p = @import("../mcu/atmega328p.zig");
const uart = @import("../hal/uart.zig");

pub fn Entry(comptime App: type) type {
    comptime {
        if (!@hasDecl(App, "main")) {
            @compileError("Applications using avr_zig.runtime.Entry must provide App.main()");
        }
    }

    return struct {
        comptime {
            std.debug.assert(std.mem.eql(u8, "RESET", std.meta.fields(atmega328p.VectorTable)[0].name));

            var asm_str: []const u8 = ".section .vectors\njmp _start\n";
            const has_interrupts = @hasDecl(App, "interrupts");

            if (has_interrupts) {
                if (@hasDecl(App.interrupts, "RESET")) {
                    @compileError("Not allowed to overload the reset vector");
                }

                for (std.meta.declarations(App.interrupts)) |decl| {
                    if (!@hasField(atmega328p.VectorTable, decl.name)) {
                        var msg: []const u8 = "There is no such interrupt as '" ++ decl.name ++ "'. ISRs in the 'interrupts' namespace must be one of:\n";
                        for (std.meta.fields(atmega328p.VectorTable)) |field| {
                            if (!std.mem.eql(u8, "RESET", field.name)) {
                                msg = msg ++ "    " ++ field.name ++ "\n";
                            }
                        }

                        @compileError(msg);
                    }
                }
            }

            for (std.meta.fields(atmega328p.VectorTable)[1..]) |field| {
                const new_instruction = if (has_interrupts) overload: {
                    if (@hasDecl(App.interrupts, field.name)) {
                        const handler = @field(App.interrupts, field.name);
                        const calling_convention = switch (@typeInfo(@TypeOf(handler))) {
                            .@"fn" => |info| info.calling_convention,
                            else => @compileError("Declarations in the 'interrupts' namespace must all be functions. '" ++ field.name ++ "' is not a function"),
                        };

                        const exported_fn = switch (calling_convention) {
                            .auto => struct {
                                fn wrapper() callconv(.avr_interrupt) void {
                                    @call(.always_inline, handler, .{});
                                }
                            }.wrapper,
                            else => @compileError("Leave interrupt handlers with an unspecified calling convention"),
                        };

                        const options: builtin.ExportOptions = .{ .name = field.name, .linkage = .strong };
                        @export(&exported_fn, options);
                        break :overload "jmp " ++ field.name;
                    } else {
                        break :overload "jmp _unhandled_vector";
                    }
                } else "jmp _unhandled_vector";

                asm_str = asm_str ++ new_instruction ++ "\n";
            }

            asm (asm_str);
        }

        pub fn unhandledVector() void {
            while (true) {}
        }

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

        pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace, _: ?usize) noreturn {
            uart.write("PANIC: ");
            uart.write(msg);

            _ = error_return_trace;
            while (true) {}
        }
    };
}
