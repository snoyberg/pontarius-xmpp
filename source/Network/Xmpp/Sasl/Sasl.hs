{-# LANGUAGE OverloadedStrings #-}

module Network.Xmpp.Sasl.Sasl where

import Network.Xmpp.Types

import           Control.Monad.Error
import           Data.Text
import qualified Data.Attoparsec.ByteString.Char8 as AP
import           Data.XML.Pickle
import           Data.XML.Types
import qualified Data.ByteString as BS
import Data.Maybe (fromMaybe)

import           Network.Xmpp.Pickle

-- The <auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/> element, with an
-- optional round-trip value.
saslInitE :: Text -> Maybe Text -> Element
saslInitE mechanism rt =
    Element "{urn:ietf:params:xml:ns:xmpp-sasl}auth"
        [("mechanism", [ContentText mechanism])]
        [NodeContent $ ContentText $ fromMaybe "" rt]

-- SASL response with text payload.
saslResponseE :: Text -> Element
saslResponseE resp =
    Element "{urn:ietf:params:xml:ns:xmpp-sasl}response"
    []
    [NodeContent $ ContentText resp]
-- SASL response without payload.
saslResponse2E :: Element
saslResponse2E =
    Element "{urn:ietf:params:xml:ns:xmpp-sasl}response"
    []
    []
-- Parses the incoming SASL data to a mapped list of pairs.
toPairs :: BS.ByteString -> Either String [(BS.ByteString, BS.ByteString)]
toPairs = AP.parseOnly . flip AP.sepBy1 (void $ AP.char ',') $ do
    AP.skipSpace
    name <- AP.takeWhile1 (/= '=')
    _ <- AP.char '='
    quote <- ((AP.char '"' >> return True) `mplus` return False)
    content <- AP.takeWhile1 (AP.notInClass [',', '"'])
    when quote . void $ AP.char '"'
    return (name, content)

-- Failure element pickler.
failurePickle :: PU [Node] SaslFailure
failurePickle = xpWrap
    (\(txt, (failure, _, _)) -> SaslFailure failure txt)
    (\(SaslFailure failure txt) -> (txt,(failure,(),())))
    (xpElemNodes
        "{urn:ietf:params:xml:ns:xmpp-sasl}failure"
        (xp2Tuple
             (xpOption $ xpElem
                  "{urn:ietf:params:xml:ns:xmpp-sasl}text"
                  xpLangTag
                  (xpContent xpId))
        (xpElemByNamespace
             "urn:ietf:params:xml:ns:xmpp-sasl"
             xpPrim
             (xpUnit)
             (xpUnit))))
-- Challenge element pickler.
challengePickle :: PU [Node] Text
challengePickle = xpElemNodes "{urn:ietf:params:xml:ns:xmpp-sasl}challenge"
                      (xpIsolate $ xpContent xpId)