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
  load,
  -- * Re-exported modules
  module Data.Ruby.Marshal.Get,
  module Data.Ruby.Marshal.Object
) where

import Data.Ruby.Marshal.Get
import Data.Ruby.Marshal.Object

import Data.Serialize.Get (runGet)

import qualified Data.ByteString as BS

-- | Deserialises a subset of Ruby objects serialised with Marshal, Ruby's
-- built-in binary serialisation format.
load :: BS.ByteString
     -- ^ Serialised Ruby object
     -> Either String RubyObject
     -- ^ De-serialisation result.
load = runGet getRubyObject
