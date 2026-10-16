{-# LANGUAGE DeriveGeneric #-}
import Codec.Serialise (Serialise, serialise, deserialise)
import Control.Monad (unless, forM_)
import qualified Data.ByteString.Lazy as Bytes
import qualified Data.Map.Strict as Map
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Set as Set
import qualified Data.IntSet as IntSet
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Data.Ratio ((%))
import GHC.Generics (Generic)

data Sample = Sample Int (Maybe Bool) deriving (Eq, Generic)
instance Serialise Sample

roundtrip :: (Eq a, Serialise a) => a -> IO ()
roundtrip value = unless (deserialise (serialise value) == value)
    (error "serialise compatibility roundtrip failed")

wire :: (Eq a, Serialise a) => a -> [Int] -> IO ()
wire value expected = do
    unless (Bytes.unpack (serialise value) == map fromIntegral expected)
        (error "serialise compatibility wire format changed")
    roundtrip value

main :: IO ()
main = do
    wire (Map.fromList [(1 :: Int, 2 :: Int), (3, 4)]) [162, 1, 2, 3, 4]
    wire (IntMap.fromList [(1, 2 :: Int), (3, 4)]) [162, 1, 2, 3, 4]
    wire (Set.fromList [1 :: Int, 2]) [130, 1, 2]
    wire (IntSet.fromList [1, 2]) [130, 1, 2]
    wire (posixSecondsToUTCTime 0) [217, 3, 232, 162, 1, 0, 43, 0]
    forM_ [(-5) % 4, 1 % 8, 1700000000123456789 % 1000000000]
        (roundtrip . posixSecondsToUTCTime . fromRational)
    roundtrip (Sample 42 (Just True))
