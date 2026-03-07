const avr = @import("avr_zig");
const pwm = avr.pwm;
const time = avr.time;

pub fn main() void {
    pwm.init(.D9);

    var duty: u8 = 0;
    var rising = true;

    while (true) {
        pwm.write(.D9, duty);
        time.sleep(4);

        if (rising) {
            if (duty == pwm.max_duty) {
                rising = false;
            } else {
                duty += 1;
            }
        } else {
            if (duty == 0) {
                rising = true;
            } else {
                duty -= 1;
            }
        }
    }
}
