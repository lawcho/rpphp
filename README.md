
# Raspberry Pi Pico HVM Platform

## Demo

`make out/led_blink1.c CLIP=1`

Paste into <https://wokwi.com/projects/new/pi-pico-sdk>

## Dependencies

* `hvm` from [this GitHub branch](https://github.com/lawcho/HVM/tree/wip/patform-io)
* The Haskell tool `stack`
* (Optional) `xsel`

## How to Debug

```
make debug/led_blink1
./debug_led_blink1
```

## Buyer Beware

This is **highly experimental** & unstable software. You have been warned!
