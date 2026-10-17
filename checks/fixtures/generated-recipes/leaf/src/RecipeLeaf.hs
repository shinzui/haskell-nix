{-# LANGUAGE CPP #-}
module RecipeLeaf (value) where
#ifdef USE_TEXT
import qualified Data.Text as Text
value :: Int
value = 42 + Text.length (Text.pack "x")
#else
value :: Int
value = 42
#endif
