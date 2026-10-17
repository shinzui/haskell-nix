module Main (main) where
import qualified RecipeLeaf as Leaf
import qualified RecipePinned as Pinned
main :: IO ()
main = print (Leaf.value + Pinned.value)
