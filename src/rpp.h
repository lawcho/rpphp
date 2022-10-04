
// Raspberry-pi specific header for use with ffi.hson

#include <stdio.h>

#ifdef DEBUG
    // In debug mode, mock the functions in ffi.hson 


    #define DEBUG_PRINTF(...) (printf(__VA_ARGS__))

    // #include<unistd.h>   // name clash with HVM's link() function
    ssize_t read(int fd, void *buf, size_t count);

    void gpio_put(uint gpio, bool value) {printf("gpio_put(%d,%d)\n",gpio,value);}
    void gpio_put_all(uint32_t value) {printf("gpio_put_all(%d)\n",value);}
    void gpio_init(uint gpio) {printf("gpio_init(%d)\n",gpio);}
    void gpio_set_dir(uint gpio,bool out) {printf("gpio_set_dir(%d,%d)\n",gpio,out);}
    void sleep_ms(uint32_t ms) {printf("sleep_ms(%d)\n",ms);}
    bool gpio_get(uint gpio) {
        char c;
        read(0,&c,1);
        printf("gpio_get(%d) (==%d)\n",gpio,c);
        return c;
    }
#else
    // Outside debug mode, let the pico SDK provide the functions in ffi.hson
    #include "pico/stdlib.h"
#endif
