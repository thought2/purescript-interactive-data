{-
# Validation and Smart Constructors

<!-- START hide -->
-}
module Manual.ComposingDataUIs.Newtypes.Validation
  ( UserId
  , demo
  , mkUserId
  ) where

{-
<!-- END hide -->
<!-- START imports -->
-}

import Prelude

import Chameleon (class Html)
import Data.Array.NonEmpty as NonEmptyArray
import Data.Either (Either(..))
import Data.String as String
import Data.String.Regex (Regex)
import Data.String.Regex as Regex
import Data.String.Regex.Flags (noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import InteractiveData (DataUI', DataResult)
import InteractiveData as ID

{-
<!-- END imports -->

## Define a newtype around a type
-}

newtype UserId = UserId String

{-

Create a smart constructor for the newtype:

-}

mkUserId
  :: String -> Either String UserId
mkUserId candidate =
  let
    result =
      Regex.test regexUserId candidate

    errorMsg = String.joinWith " "
      [ "Invalid UserId."
      , "Must be 8 characters long."
      , "Only lowercase letters and numbers."
      ]
  in
    if result then
      Right (UserId candidate)
    else
      Left errorMsg

regexUserId :: Regex
regexUserId =
  unsafeRegex "^[a-z0-9]{8}$" noFlags

{-

## Define Instances

-}

instance Show UserId where
  show (UserId s) =
    "(unsafeFromString "
      <> show s
      <> ")"

{-

## Composing a Data UI for the newtype

And then compose a data UI for it:

-}

demo
  :: forall html
   . Html html
  => DataUI' html _ _ UserId
demo =
  ID.refineDataUi
    { typeName: "UserId"
    , refine
    , unrefine
    }
    (ID.string { multiline: false })

  where
  refine :: String -> DataResult UserId
  refine candidate =
    case mkUserId candidate of
      Right userId ->
        Right userId

      Left errorMsg ->
        Left $ NonEmptyArray.singleton $
          ID.mkDataError errorMsg

  unrefine :: UserId -> String
  unrefine (UserId s) = s

{-


The UI will look like this:

<!-- START embed validation 500 -->
<!-- END embed -->
-}