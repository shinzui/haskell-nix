{-# LANGUAGE CPP #-}
module ValidationFixture (value) where

value :: Int
#ifdef COMPATIBILITY_REPAIR
value = 42
#else
value = 0
#endif
