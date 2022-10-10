
# Raspberry Pi Pico HVM Platform

## Demo

```
git clone https://github.com/lawcho/rpphp --recurse-submodules
cd rpphp
make out/led_blink1.c CLIP=1
```

Paste into <https://wokwi.com/projects/new/pi-pico-sdk>

## Dependencies

* The Rust tool `cargo` (for building `hvm`)
* The Haskell tool `stack` (for running `platgen.hs`)
* `xsel` (Optional, for copying to clipboard)
* `cmake`,`gcc`, etc. (Optional, for building bare-metal binaries)

## How to Debug

```
make debug/led_blink1
./debug_led_blink1
```

## Buyer Beware

This is **highly experimental** & unstable software. You have been warned!
