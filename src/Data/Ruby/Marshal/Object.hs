{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE PatternSynonyms #-}

--------------------------------------------------------------------
-- |
-- Module    : Data.Ruby.Marshal.Object
-- Copyright : (c) Philip Cunningham, 2015
-- License   : MIT
--
-- Maintainer:  hello@filib.io
-- Stability :  experimental
-- Portability: portable
--
-- RubyObject definition.
--
--------------------------------------------------------------------

module Data.Ruby.Marshal.Object (
  RubyObject(..),
  getRubyObject
) where

import Control.Applicative
import Data.Ruby.Marshal.Get
import Prelude

import Data.Serialize.Get  (Get, getWord8)
import Data.Vector         (Vector)

import qualified Data.ByteString as BS

data Error
  = Unknown
    -- ^ represents an unknown Ruby object
  | Unsupported
    -- ^ represents an unsupported Ruby object
  deriving (Eq, Show)

data RubyObject
  = RNil
    -- ^ represents @nil@
  | RBool                  !Bool
    -- ^ represents @true@ or @false@
  | RFixnum {-# UNPACK #-} !Int
    -- ^ represents a @Fixnum@
  | RArray                 !(Vector RubyObject)
    -- ^ represents an @Array@
  | RHash                  !(Vector (RubyObject, RubyObject))
    -- ^ represents an @Hash@
  | RString                !BS.ByteString
    -- ^ represents a @String@
  | RFloat                 !Double
    -- ^ represents a @Float@
  | RError                 !Error
    -- ^ represents an invalid object
  deriving (Eq, Show)

pattern NilC    = 48
pattern TrueC   = 84
pattern FalseC  = 70
pattern FixnumC = 105
pattern ArrayC  = 91
pattern HashC   = 123
pattern IvarC   = 73
pattern StringC = 34
pattern FloatC  = 102

-- | Parses a subset of Ruby objects.
getRubyObject :: Get RubyObject
getRubyObject = getWord8 >>= \case
  NilC    -> return RNil
  TrueC   -> return $ RBool True
  FalseC  -> return $ RBool False
  FixnumC -> RFixnum <$> getFixnum
  ArrayC  -> RArray  <$> getArray getRubyObject
  HashC   -> RHash   <$> getHash getRubyObject getRubyObject
  IvarC   -> getWord8 >>= \case StringC -> RString <$> getString getRubyObject
                                _       -> unsupported
  FloatC  -> RFloat <$> getFloat
  _       -> unsupported
  where
    unsupported = return $ RError Unsupported
