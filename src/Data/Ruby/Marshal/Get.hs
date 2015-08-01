{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}

--------------------------------------------------------------------
-- |
-- Module    : Data.Ruby.Marshal.Get
-- Copyright : (c) Philip Cunningham, 2015
-- License   : MIT
--
-- Maintainer:  hello@filib.io
-- Stability :  experimental
-- Portability: portable
--
-- Ruby Marshal deserialiser using @Data.Serialize@.
--
--------------------------------------------------------------------

module Data.Ruby.Marshal.Get (
    -- * Ruby Marshal parsers
    getMarshalVersion
  , getRubyObject
) where

import Control.Applicative
import Data.Ruby.Marshal.Int
import Data.Ruby.Marshal.Types
import Prelude

import Control.Monad              (liftM2)
import Data.Ruby.Marshal.Encoding (toEnc)
import Data.Ruby.Marshal.Monad    (liftMarshal, readObject, readSymbol, writeCache)
import Data.Serialize.Get         (Get, getBytes, getTwoOf, label)
import Data.String.Conv           (toS)
import Text.Read                  (readMaybe)

import qualified Data.ByteString as BS
import qualified Data.Vector     as V

--------------------------------------------------------------------
-- Top-level functions.

-- | Deserialises Marshal version.
getMarshalVersion :: Marshal (Word8, Word8)
getMarshalVersion = liftAndLabel "Marshal Version" $
  getTwoOf getWord8 getWord8 >>= \version -> case version of
    (4, 8) -> return version
    _      -> fail "marshal version unsupported"

-- | Deserialises a subset of Ruby objects.
getRubyObject :: Marshal RubyObject
getRubyObject = getMarshalVersion >> go
  where
    go :: Marshal RubyObject
    go = liftMarshal getWord8 >>= \case
      NilChar        -> return RNil
      TrueChar       -> return $ RBool True
      FalseChar      -> return $ RBool False
      ArrayChar      -> RArray  <$> getArray go
      FixnumChar     -> RFixnum <$> getFixnum
      FloatChar      -> RFloat  <$> getFloat
      HashChar       -> RHash   <$> getHash go go
      IVarChar       -> RIVar   <$> getIVar go
      ObjectLinkChar -> RIVar   <$> getObjectLink
      StringChar     -> RString <$> getString
      SymbolChar     -> RSymbol <$> getSymbol
      SymlinkChar    -> RSymbol <$> getSymlink
      _              -> return Unsupported

--------------------------------------------------------------------
-- Ancillary functions.

-- | Deserialises <http://ruby-doc.org/core-2.2.0/Array.html Array>.
getArray :: Marshal a -> Marshal (V.Vector a)
getArray g = marshalLabel "Fixnum" $ do
  n <- getFixnum
  x <- V.replicateM n g
  return x

-- | Deserialises <http://ruby-doc.org/core-2.2.0/Fixnum.html Fixnum>.
getFixnum :: Marshal Int
getFixnum = liftAndLabel "Fixnum" $ do
  x <- getInt8
  if | x ==  0   -> fromIntegral <$> return x
     | x ==  1   -> fromIntegral <$> getWord8
     | x == -1   -> fromIntegral <$> getNegInt16
     | x ==  2   -> fromIntegral <$> getWord16le
     | x == -2   -> fromIntegral <$> getInt16le
     | x ==  3   -> fromIntegral <$> getWord24le
     | x == -3   -> fromIntegral <$> getInt24le
     | x ==  4   -> fromIntegral <$> getWord32le
     | x == -4   -> fromIntegral <$> getInt32le
     | x >=  6   -> fromIntegral <$> return (x - 5)
     | x <= -6   -> fromIntegral <$> return (x + 5)
     | otherwise -> empty
  where
    getNegInt16 :: Get Int16
    getNegInt16 =  do
      x <- fromIntegral <$> getInt8
      if x >= 0 && x <= 127 then return (x - 256) else return x

-- | Deserialises <http://ruby-doc.org/core-2.2.0/Float.html Float>.
getFloat :: Marshal Float
getFloat = marshalLabel "Float" $ do
  s <- getString
  x <- case readMaybe . toS $ s of
    Just float -> return float
    Nothing    -> fail "expected float"
  return x

-- | Deserialises <http://ruby-doc.org/core-2.2.0/Hash.html Hash>.
getHash :: Marshal a -> Marshal b -> Marshal (V.Vector (a, b))
getHash k v = marshalLabel "Hash" $ do
  n <- getFixnum
  x <- V.replicateM n (liftM2 (,) k v)
  return x

-- | Deserialises <http://docs.ruby-lang.org/en/2.1.0/marshal_rdoc.html#label-Instance+Variables Instance Variables>.
getIVar :: Marshal RubyObject -> Marshal (RubyObject, REncoding)
getIVar g = marshalLabel "IVar" $ do
  str <- g
  len <- getFixnum
  if | len /= 1 -> fail "expected single character"
     | otherwise   -> do
       symbol <- g
       denote <- g
       case symbol of
         RSymbol "E" -> case denote of
           RBool True  -> return' (str, UTF_8)
           RBool False -> return' (str, US_ASCII)
           _           -> fail "expected bool"
         RSymbol "encoding" -> case denote of
           RString enc -> return' (str, (toEnc enc))
           _           -> fail "expected string"
         _          -> fail "invalid ivar"
  where
    return' result = do
      writeCache $ RIVar result
      return result

-- | Pulls an Instance Variable out of the object cache.
getObjectLink :: Marshal (RubyObject, REncoding)
getObjectLink = marshalLabel "ObjectLink" $ do
  index <- getFixnum
  maybeObject <- readObject index
  case maybeObject of
    Just (RIVar x) -> return x
    _              -> fail "invalid object link"

-- | Deserialises <http://ruby-doc.org/core-2.2.0/String.html String>.
getString :: Marshal BS.ByteString
getString = marshalLabel "RawString" $ do
  n <- getFixnum
  x <- liftMarshal $ getBytes n
  return x

-- | Deserialises <http://ruby-doc.org/core-2.2.0/Symbol.html Symbol>.
getSymbol :: Marshal BS.ByteString
getSymbol = marshalLabel "Symbol" $ do
  x <- getString
  writeCache $ RSymbol x
  return x

-- | Pulls a Symbol out of the symbol cache.
getSymlink :: Marshal BS.ByteString
getSymlink = marshalLabel "Symlink" $ do
  index <- getFixnum
  maybeObject <- readSymbol index
  case maybeObject of
    Just (RSymbol bs) -> return bs
    _                 -> fail "invalid symlink"

--------------------------------------------------------------------
-- Utility functions.

-- | Lift Get into Marshal monad and then label.
liftAndLabel :: String -> Get a -> Marshal a
liftAndLabel x y = liftMarshal $! label x y

-- | Label underlying Get in Marshal monad.
marshalLabel :: String -> Marshal a -> Marshal a
marshalLabel x y = y >>= \y' -> liftMarshal $! label x (return y')
