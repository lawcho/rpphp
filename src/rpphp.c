// Raspberry Pi Pico HVM Platform

// Protocol:
// Every 0.5s:
//  1. Evalaute main term (intially (Main))
//  2. Decode main term, expecting (FFI.call func cont)
//  3. Decode func, expecting
//    func == (CFun.gpio_put pin lohi)
//         or (CFun.gpio_put_all bits)
//         or (CFun.gpio_get pin)
//         or (CFun.gpio_init pin)
//         or (CFun.gpio_set_dir pin dir)
//         or (CFun.sleep_ms millis)
//  4. Evalaute args of decoded func
//  5. Decode args, expecting...
//    pin     == n           (n an int <= 2^32)
//    bits    == n           (n an int <= 2^32)
//    millis  == n           (n an int <= 2^32)
//    lohi    == FFI.true
//            or FFI.false
//    dir     == FFI.true   (i.e. output pin)
//            or FFI.false  (i.e. input pin)
//  6. Call approriate C function
//  7. Encode C function return value as HVM-expression e (NUM 0 for void)
//  7. Replace main term with (cont e)

// API based off
// https://raspberrypi.github.io/pico-sdk-doxygen/group__hardware__gpio.html

#include <stdio.h>
#include <stdbool.h>
#ifndef DEBUG
#include "pico/stdlib.h"
#endif

#ifndef _FFI_CALL_
#define _FFI_CALL_ (ID_TO_NAME_SIZE +1)
#endif
#ifndef _FFI_TRUE_
#define _FFI_TRUE_ (ID_TO_NAME_SIZE +2)
#endif
#ifndef _FFI_FALSE_
#define _FFI_FALSE_ (ID_TO_NAME_SIZE +3)
#endif
#ifndef _CFUN_SLEEP__MS_
#define _CFUN_SLEEP__MS_ (ID_TO_NAME_SIZE +4)
#endif
#ifndef _CFUN_GPIO__INIT_
#define _CFUN_GPIO__INIT_ (ID_TO_NAME_SIZE +5)
#endif
#ifndef _CFUN_GPIO__SET__DIR_
#define _CFUN_GPIO__SET__DIR_ (ID_TO_NAME_SIZE +6)
#endif
#ifndef _CFUN_GPIO__PUT_
#define _CFUN_GPIO__PUT_ (ID_TO_NAME_SIZE +7)
#endif
#ifndef _CFUN_GPIO__PUT__ALL_
#define _CFUN_GPIO__PUT__ALL_ (ID_TO_NAME_SIZE +8)
#endif
#ifndef _CFUN_GPIO__GET_
#define _CFUN_GPIO__GET_ (ID_TO_NAME_SIZE +9)
#endif

// HVM -> C marshalling functions

bool decode_bool(Ptr cell){
  assert(get_tag(cell) == CTR);
  assert(get_ext(cell) == _FFI_TRUE_ | get_ext(cell) == _FFI_FALSE_);
  if (get_ext(cell) == _FFI_TRUE_) {return true;}
  if (get_ext(cell) == _FFI_FALSE_) {return false;}
  assert (false);
  return 0;
}

int decode_u32(Ptr cell) {
  assert(get_tag(cell) == NUM);
  assert(get_num(cell) <= UINT32_MAX);
  return get_num(cell);
}

// C -> HVM marshalling functions

Ptr encode_void(){
  return Num(0);
}

Ptr encode_bool(bool value){
  if (value) {
    return Ctr(0,_FFI_TRUE_,0);
  } else {
    return Ctr(0,_FFI_FALSE_,0);
  }
}

Worker* wp;

#ifdef DEBUG

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

static char* str_unknown = "???";
char * decode_cid(u64 cid){
    if (cid < ID_TO_NAME_SIZE) {
        return id_to_name_data[cid];
    } else {
        return str_unknown;
    }
}

void debug_print_cell(Ptr x) {
  u64 tag = get_tag(x);
  u64 ext = get_ext(x);
  u64 val = get_val(x);
  u64 num = get_num(x);
  switch (tag) {
    case DP0: printf("[DP0 | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case DP1: printf("[DP1 | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case VAR: printf("[VAR | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case ARG: printf("[ARG | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case ERA: printf("[ERA | %22s | %22s ]\n",                      "",     ""  ); break;
    case LAM: printf("[LAM | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case APP: printf("[APP | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case SUP: printf("[SUP | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case CTR: printf("[CTR | %22s | 0x%-20"PRIX64" ]\n", decode_cid(ext),   val ); break;
    case FUN: printf("[FUN | %22s | 0x%-20"PRIX64" ]\n", decode_cid(ext),   val ); break;
    case OP2: printf("[OP2 | 0x%-20"PRIu64" | 0x%-20"PRIX64" ]\n",  ext,    val ); break;
    case NUM: printf("[NUM | %47"PRIu64" ]\n",                              num ); break;
    default : printf("[ ?????????        0x%-16"PRIX64"        ????????? ]\n", x ); break;
  }
}

void dump(){
    for (u64 i = 0; i < wp->size; i ++){
        printf("0x%-5"PRIX64"",i);
        debug_print_cell(wp->node[i]);
    }
}

#endif

int main() {

  Worker hvm_mem;
  wp = &hvm_mem;
  build_main_term_with_args(wp,_MAIN_,0,(char**)0);

  while(true){
    // Step 1
    Ptr main_term = whnf(wp,0);

    assert(get_tag(main_term) == CTR);
    assert(get_ext(main_term) == _FFI_CALL_);

    u64 func_p = get_loc(main_term,0);
    u64 cont_p = get_loc(main_term,1);

    Ptr func =    whnf(wp, func_p);
    Ptr cont = ask_lnk(wp, cont_p);

    Ptr ret_exp;

    assert(get_tag(func) == CTR);
    u64 args_p = get_loc(func,0);

    switch (get_ext(func)) {
      case _CFUN_GPIO__PUT_:{
        gpio_put
          ( decode_u32 (whnf(wp, args_p + 0))
          , decode_bool(whnf(wp, args_p + 1))
          );
        clear(wp,args_p, 2);
        ret_exp = encode_void();
        break;
      }
      case _CFUN_GPIO__PUT__ALL_:{
        gpio_put_all
          ( decode_u32 (whnf(wp, args_p + 0))
          );
        clear(wp,args_p, 1);
        ret_exp = encode_void();
        break;
      }
      case _CFUN_GPIO__GET_:{
        bool val = gpio_get
          ( decode_u32 (whnf(wp, args_p + 0))
          );
        clear(wp,args_p, 1);
        ret_exp = encode_bool(val);
        break;
      }
      case _CFUN_GPIO__INIT_:{
        gpio_init
          ( decode_u32 (whnf(wp, args_p + 0))
          );
        clear(wp,args_p, 1);
        ret_exp = encode_void();
        break;
      }
      case _CFUN_GPIO__SET__DIR_:{
        gpio_set_dir
          ( decode_u32 (whnf(wp, args_p + 0))
          , decode_bool(whnf(wp, args_p + 1))
          );
        clear(wp,args_p, 2);
        ret_exp = encode_void();
        break;
      }
      case _CFUN_SLEEP__MS_:{
        sleep_ms
          ( decode_u32 (whnf(wp, args_p + 0))
          );
        clear(wp,args_p, 1);
        ret_exp = encode_void();
        break;
      }
      default:{
        assert(false);
        break;
      }
    }
    // Cleanup: free old main term's ctr-data node: [func][rest]
    clear(wp, func_p, 2);

    // Step 7
    u64 app_data_p = alloc(wp, 2);
    link(wp, 0, App(app_data_p));
    link(wp, app_data_p + 0, cont);
    link(wp, app_data_p + 1, ret_exp);
  }
}
