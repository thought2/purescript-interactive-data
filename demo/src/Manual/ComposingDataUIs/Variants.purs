{-
# Data UIs for Variant types

<!-- START hide -->
-}
module Manual.ComposingDataUIs.Variants where

{-
<!-- END hide -->
<!-- START imports -->
-}

import Chameleon (class Html)
import Data.Variant (Variant)
import InteractiveData (DataUI')
import InteractiveData as ID

{-
<!-- END imports -->

## Defining a variant type

Define a variant type first:
-}

type RemoteData = Variant
  ( notAsked :: {}
  , loading :: { progress :: Number }
  , failed ::
      { errorMessage :: String
      , errorCode :: Int
      }
  , success :: { data :: String }
  )

{-

## Composing a Data UI for a variant type

And then compose a data UI for it:

-}

demoVariant
  :: forall html
   . Html html
  => DataUI' html _ _ RemoteData
demoVariant =
  ID.variant_ @"notAsked"
    { notAsked:
        ID.record_ {}
    , loading:
        ID.record_
          { progress: ID.number_ }
    , failed:
        ID.record_
          { errorMessage: ID.string_
          , errorCode: ID.int_
          }
    , success:
        ID.record_
          { data: ID.string_ }
    }

{-

The UI will look like this:

<!-- START embed variant 500 -->
<!-- END embed -->
-}