module Exports where

import Control.Exception (SomeException, try)
import Foreign.C.String (CString, newCString, peekCString)
import Foreign.Ptr (Ptr)
import Main (appInit, callocBuffer, freeBuffer, handler)

foreign export ccall "dispatch" dispatch :: CString -> IO CString

foreign export ccall "appInit" appInit :: IO ()

foreign export ccall "callocBuffer" callocBuffer :: Int -> IO (Ptr a)

foreign export ccall "freeBuffer" freeBuffer :: Ptr a -> IO ()

dispatch :: CString -> IO CString
dispatch input = do
  raw <- peekCString input
  result <- try (handler raw)
  case result of
    Left (e :: SomeException) -> error $ show e
    Right val -> newCString val