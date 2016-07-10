{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module WarpBench where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson
       (ToJSON, encode, toEncoding, toJSON, genericToEncoding,
        defaultOptions)
import Data.ByteString (ByteString)
import Data.Text.Encoding (decodeUtf8)
import Data.Int (Int32)
import Data.Vector as V (Vector, mapM)
import GHC.Generics (Generic)
import Hasql.Pool (Pool, use)
import Hasql.Query (Query, statement)
import Hasql.Session (query)
import Hasql.Decoders (bytea, int4, rowsVector, value)
import Hasql.Encoders (unit)
import Lucid
       (Html, renderBS, doctypehtml_, head_, body_, title_, table_,
        toHtml, tr_, td_)
import Network.Wai (Application, rawPathInfo, responseLBS)
import Network.HTTP.Types (status200, status404)
import Network.HTTP.Types.Header (hContentType)

data Fortune =
  Fortune {mid :: !Int32
          ,msg :: ByteString}
  deriving (Show,Generic)

instance ToJSON Fortune where
  toEncoding = genericToEncoding defaultOptions

instance ToJSON ByteString where
  toJSON bs = toJSON (decodeUtf8 bs)

app :: Pool -> Application
app pool req respond = 
  case rawPathInfo req of
    "/hello" -> 
      respond $
      responseLBS status200
                  [(hContentType,"text/plain")]
                  "Hello world!"
    "/fortunes" -> fortunesHTML pool respond
    "/fortunes.json" -> fortunesJSON pool respond
    _ -> respond $ responseLBS status404 [] ""

fortuneQuery :: Query () (Vector Fortune)
fortuneQuery = statement query encoder decoder True
  where query = "SELECT * FROM fortunes"
        encoder = unit
        decoder = rowsVector $ Fortune <$> value int4 <*> value bytea

fortunesHTML pool respond = 
  do (Right fortunes) <- liftIO $ use pool (query () fortuneQuery)
     respond $
       responseLBS status200
                   [(hContentType,"text/html; charset=utf-8")]
                   (present fortunes)

present fortunes = renderBS $
  doctypehtml_ $
  do head_ $ title_ "Fortune Cookie Messages"
     body_ $ table_ $ V.mapM present' fortunes

present' fortune = 
    tr_ (do td_ . toHtml . show $ mid fortune
            td_ . toHtml . decodeUtf8 $ msg fortune) :: Html ()

fortunesJSON pool respond = 
  do (Right fortunes) <- liftIO $ use pool (query () fortuneQuery)
     respond $
       responseLBS status200
                   [(hContentType,"application/json; charset=utf-8")]
                   (encode fortunes)
