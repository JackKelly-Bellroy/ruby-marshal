--------------------------------------------------------------------
-- |
-- Module    : Data.Ruby.Marshal
-- Copyright : (c) Philip Cunningham, 2015
-- License   : MIT
--
-- Maintainer:  hello@filib.io
-- Stability :  experimental
-- Portability: portable
--
-- Simple interface to deserialise Ruby Marshal binary.
--
--------------------------------------------------------------------

module Data.Ruby.Marshal (
  -- * Simple interface to deserialise Ruby Marshal binary
  decode,
  -- * Re-exported modules
  module Data.Ruby.Marshal.Get,
  module Data.Ruby.Marshal.Types
) where

import Data.Ruby.Marshal.Get
import Data.Ruby.Marshal.Types (Cache(..), RubyObject(..), Marshal(..))

import Control.Monad.State (evalStateT)
import Data.Serialize      (runGet)

import qualified Data.ByteString as BS
import qualified Data.Vector     as V

-- | Constructs an empty cache to store symbols and objects.
emptyCache :: Cache
emptyCache = Cache { _symbols = V.empty, _objects = V.empty }

-- | Converts an Either to a Maybe.
fromEitherToMaybe :: Either a b -> Maybe b
fromEitherToMaybe (Left  _) = Nothing
fromEitherToMaybe (Right x) = Just x

-- | Deserialises a subset of Ruby objects serialised with Marshal, Ruby's
-- built-in binary serialisation format.
decode :: BS.ByteString
     -- ^ Serialised Ruby object
     -> Maybe RubyObject
     -- ^ De-serialisation result
decode x = fromEitherToMaybe $
  runGet (evalStateT (runMarshal getRubyObject) emptyCache) x
