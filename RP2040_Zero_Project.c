#include <stdio.h>
#include <stdlib.h>

#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "ws2812.pio.h"

void put_pixel(uint32_t pixel_grb)
{
    // Write a word of data (32 bit color val) to a state machine’s TX FIFO, blocking if the FIFO is full.
    // You shift 8 bits to the left because it expects
    // 24 bits of color data to be left-aligned in the FIFO buffer.
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}
void put_rgb(uint8_t red, uint8_t green, uint8_t blue)
{
    // You store all 3 values into a 32bit mask in the correct order (GRB, not RGB)
    uint32_t mask = (green << 16) | (red << 8) | (blue << 0);
    put_pixel(mask);
}

int main()
{
    //set_sys_clock_48();
    stdio_init_all();

    PIO pio = pio0;
    int sm = 0;
    // pio_add_program will load instructions from ws2812.pio.h into PIO hardware mem
    uint offset = pio_add_program(pio, &ws2812_program);
    uint8_t cnt = 0;

    puts("RP2040-Zero WS2812 Project");

    // Configure state machine (GPIO pin = 16, freq = 800kHz, true for RGBW)
    ws2812_program_init(pio, sm, offset, 16, 800000, true);

    while (1)
    {
        // Fade in/out green, red, blue
        for (cnt = 0; cnt < 0xff; cnt++)
        {
            put_rgb(cnt, 0xff - cnt, 0);
            sleep_ms(3);
        }
        for (cnt = 0; cnt < 0xff; cnt++)
        {
            put_rgb(0xff - cnt, 0, cnt);
            sleep_ms(3);
        }
        for (cnt = 0; cnt < 0xff; cnt++)
        {
            put_rgb(0, cnt, 0xff - cnt);
            sleep_ms(3);
        }
    }
}
