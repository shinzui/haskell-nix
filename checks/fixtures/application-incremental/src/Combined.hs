module Combined (combined) where

import Leaf (leaf)
import Stable (stable)

combined :: Int
combined = stable + leaf
