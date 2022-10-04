#! /usr/bin/env stack
{- stack script
 --resolver lts-18.28
 --package text
 --package raw-strings-qq
-}

-- Haskell script to generate HVM platform,
-- given list of C FFI functions and glue

{-# LANGUAGE OverloadedStrings, QuasiQuotes #-}
module PlatGen where
import System.Environment (getArgs)
import Data.Text (Text)
import qualified Data.Text as Text
import Text.RawString.QQ


main :: IO()
main = do
  [ffi_file, hdr_file] <- getArgs
  ffi <- (read <$> readFile ffi_file) :: IO [FunSig]
  hdr <- (Text.pack <$> readFile hdr_file)

  putStrLn
    $ Text.unpack
    $ Text.replace "////GENERATED_HEADER////" hdr
    $ Text.replace "////GENERATED_CID_IFNDEF_DEFINES////" (genDefines ffi)
    $ Text.replace "////GENERATED_CASES////" (genCases ffi)
    $ Text.pack template

-- Implementation details below this line
-- --------------------------------------

-- Supported types
data ArgTy
    = T_uint32_t
    | T_uint
    | T_bool
  deriving (Read,Eq)

data RetTy
    = Void
    | Ret ArgTy
  deriving (Read,Eq)

data FunSig = CSig RetTy Text [ArgTy]
  deriving (Read)

type RawFunName = Text
type CompiledName = Text

-- Mimic HVM's name mangling (after prepending "CFun.")
-- (at time of writing, this was implemented at
--  https://github.com/Kindelia/HVM/blob/1336bb326db40d71eb09b306ddeeb8800f0c1f16/src/compiler.rs#L32)
compileName :: RawFunName -> CompiledName
compileName text = Text.toUpper $
  "_" <> (Text.replace "." "_" $ Text.replace "_" "__" $ "CFun." <> text) <> "_"

printType :: ArgTy -> Text
printType T_uint = "uint"
printType T_bool = "bool"
printType T_uint32_t = "uint32_t"

getCompiledName :: FunSig -> CompiledName
getCompiledName (CSig _ rName _) = compileName rName

-- Generate a list of (re) #define s for CIDs
genDefines :: [FunSig] -> Text
genDefines = Text.unlines . map go . zip [0..] . map getCompiledName where
  go (i,compiledName) = Text.unlines $ map Text.unwords $
    [ ["#ifndef",compiledName]
    , ["#define",compiledName,"(GENERATED_CID_START + ", (Text.pack $ show i),")"]
    , ["#endif"]
    ]

-- Generate arg-eval/decoding code
genDecodeArgs :: [ArgTy] -> [Text]
genDecodeArgs = map go . zip [0..] where
    go (i,argTy) = Text.unwords $
      [ "decode_" <> printType argTy
      , "(whnf(wp, args_p +"
      , (Text.pack $ show i)
      , "))"
      ]

-- Generate case-handling code
genCases :: [FunSig] -> Text
genCases = Text.unlines . map go where
  go (CSig retTy rName args) = Text.unlines . map Text.unwords $
    [ ["case",compileName rName,":{"]
    , ["ret_term =",
          case retTy of
            Void     -> "encode_void();"
            (Ret ty) -> "encode_" <> printType ty]
    , ["(",rName, "("]
    , [Text.intercalate ",\n" (genDecodeArgs args)]
    , ["));"]
    , ["clear(wp,args_p,",(Text.pack $ show $ length args),");"]
    , ["break;}"]
    ]

template :: String
template = [r|

// HVM Platform template
// /////////////////////

// Platform-independent helpers

#include <stdbool.h>
#include <limits.h>

#ifndef _FFI_CALL_
#define _FFI_CALL_ (ID_TO_NAME_SIZE +0)
#endif
#ifndef _FFI_TRUE_
#define _FFI_TRUE_ (ID_TO_NAME_SIZE +1)
#endif
#ifndef _FFI_FALSE_
#define _FFI_FALSE_ (ID_TO_NAME_SIZE +2)
#endif
// (we don't #define _MAIN_, since we want compilation to fail if (Main) is missing)

#define GENERATED_CID_START (ID_TO_NAME_SIZE +3)

// Generated default CIDs for FFI functions

////GENERATED_CID_IFNDEF_DEFINES////

// Platform-independent marshalling functions

// HVM -> C

bool decode_bool(Ptr cell){
  assert(get_tag(cell) == CTR);
  assert(get_ext(cell) == _FFI_TRUE_ | get_ext(cell) == _FFI_FALSE_);
  if (get_ext(cell) == _FFI_TRUE_) {return true;}
  if (get_ext(cell) == _FFI_FALSE_) {return false;}
  assert (false);
  return 0;
}

int decode_uint32_t(Ptr cell) {
  assert(get_tag(cell) == NUM);
  assert(get_num(cell) <= UINT32_MAX);
  return get_num(cell);
}

int decode_uint(Ptr cell) {
  assert(get_tag(cell) == NUM);
  assert(get_num(cell) <= UINT_MAX);
  return get_num(cell);
}

// C -> HVM

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

void dump(Worker* wp);

// Platform-specific C code

////GENERATED_HEADER////

// Platform-independent debug helpers

#ifndef DEBUG_PRINTF
  #define DEBUG_PRINTF(...) (0)
#endif

static char* str_unknown = "???";
char * decode_cid(u64 cid){
  if (cid < ID_TO_NAME_SIZE) {
    return id_to_name_data  [cid];
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
    case DP0: DEBUG_PRINTF("[DP0 | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case DP1: DEBUG_PRINTF("[DP1 | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case VAR: DEBUG_PRINTF("[VAR | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case ARG: DEBUG_PRINTF("[ARG | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case ERA: DEBUG_PRINTF("[ERA | %22s | %22s ]\n",                      "",     ""  ); break;
    case LAM: DEBUG_PRINTF("[LAM | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case APP: DEBUG_PRINTF("[APP | %22s | 0x%-20"PRIX64" ]\n",            "",     val ); break;
    case SUP: DEBUG_PRINTF("[SUP | %-22"PRIu64" | 0x%-20"PRIX64" ]\n",    ext,    val ); break;
    case CTR: DEBUG_PRINTF("[CTR | %22s | 0x%-20"PRIX64" ]\n", decode_cid(ext),   val ); break;
    case FUN: DEBUG_PRINTF("[FUN | %22s | 0x%-20"PRIX64" ]\n", decode_cid(ext),   val ); break;
    case OP2: DEBUG_PRINTF("[OP2 | 0x%-20"PRIu64" | 0x%-20"PRIX64" ]\n",  ext,    val ); break;
    case NUM: DEBUG_PRINTF("[NUM | %47"PRIu64" ]\n",                              num ); break;
    default:  DEBUG_PRINTF("[ ?????????        0x%-16"PRIX64"        ????????? ]\n", x); break;
  }
}

void dump(Worker* wp){
  for (u64 i = 0; i < wp->size; i ++){
    DEBUG_PRINTF("0x%-5"PRIX64"",i);
    debug_print_cell(wp->node[i]);
  }
}

// Main loop

int main() {

  Worker hvm_mem;
  Worker* wp = &hvm_mem;
  build_main_term_with_args(wp,_MAIN_,0,(char**)0);

  while(true){
    // Evaluate main term
    Ptr main_term = whnf(wp,0);

    // Attempt to decode main term as (FFI.call func cont)
    assert(get_tag(main_term) == CTR);
    assert(get_ext(main_term) == _FFI_CALL_);

    u64 func_p = get_loc(main_term,0);
    u64 cont_p = get_loc(main_term,1);

    // Evaluate func
    Ptr func = whnf(wp, func_p);

    // Generated glue code attempts to:
    //  1. Decode func as (<CTR> arg1 arg2 arg3...)
    //      where <CTR> is one of the FFI functions (platform specific)
    //  2. Evalaute args
    //  3. Marshall args HVM -> C
    //  4. Call FFI function
    //  5. Marshall return value C -> HVM
    //  6. Free args
    assert(get_tag(func) == CTR);
    u64 args_p = get_loc(func,0);
    Ptr ret_term;
    switch (get_ext(func)) {

      // Generated FFI glue 

////GENERATED_CASES////

      default: {
        u64 cid = get_ext(func);
        DEBUG_PRINTF("Illegal FFI call! cid=%"PRIu64",decoded=%s\n",cid,decode_cid(cid));
        dump(wp);
        assert(false);
        return 1;
      }
    }
    // Cleanup: free old main term's ctr-data node: [func][cont]
    clear(wp, func_p, 2);

    Ptr cont = ask_lnk(wp, cont_p);

    // replace main term with (cont ret_term)
    u64 app_data_p = alloc(wp, 2);
    link(wp, 0, App(app_data_p));
    link(wp, app_data_p + 0, cont);
    link(wp, app_data_p + 1, ret_term);
  }
}

|]
