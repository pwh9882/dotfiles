/*
 * set-capslock-led - Control Caps Lock LED independently of modifier state.
 * Usage: set-capslock-led <0|1>
 *
 * Uses IOKit to directly set the Caps Lock LED state.
 * Designed for use with Karabiner-Elements (manipulate_caps_lock_led: false)
 * to sync LED with HJKL mode without activating the Caps Lock modifier.
 */
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <stdbool.h>

/* Private IOKit HID function - available in IOKit.framework */
extern kern_return_t IOHIDSetModifierLockState(io_connect_t, int, bool);

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    bool state = argv[1][0] == '1';

    io_service_t svc = IOServiceGetMatchingService(
        MACH_PORT_NULL, IOServiceMatching("IOHIDSystem"));
    if (!svc) return 1;

    io_connect_t conn;
    kern_return_t kr = IOServiceOpen(
        svc, mach_task_self(), 1 /* kIOHIDParamConnectType */, &conn);
    IOObjectRelease(svc);
    if (kr != KERN_SUCCESS) return 1;

    IOHIDSetModifierLockState(conn, 1 /* kIOHIDCapsLockState */, state);
    IOServiceClose(conn);
    return 0;
}
