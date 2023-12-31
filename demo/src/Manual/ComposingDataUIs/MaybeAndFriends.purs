{-
# Maybe and friends

<!-- START hide -->
-}
module Manual.ComposingDataUIs.MaybeAndFriends where

{-
<!-- END hide -->
<!-- START imports -->
-}

import Prelude

import Chameleon (class Html)
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple)
import InteractiveData (DataUI')
import InteractiveData as ID

{-
<!-- END imports -->

The interactive-data library provides Data UIs for common data types
like `Maybe`, `Either` and `Tuple`.


# Maybe

-}

demoMaybe
  :: forall html
   . Html html
  => DataUI' html _ _ (Maybe Int)
demoMaybe =
  ID.maybe
    { text: Just "Call me maybe.." }
    ID.int_

{-

<!-- START embed maybe 500 -->
<!-- END embed -->

# Either

-}

demoEither
  :: forall html
   . Html html
  => DataUI' html _ _
       (Either String Int)
demoEither =
  ID.either
    { text: Just
        "Some Result or some Error"
    }
    ID.string_
    ID.int_

{-

<!-- START embed either 500 -->
<!-- END embed -->

# Tuple

-}

demoTuple
  :: forall html
   . Html html
  => DataUI' html _ _
       (Tuple Int String)
demoTuple =
  ID.tuple
    { text: Just "Int and String" }
    ID.int_
    ID.string_

{-

<!-- START embed tuple 500 -->
<!-- END embed -->

# Unit

There's even a Data UI for the unit type.
It's useful in some cases. But it's UI is just empty.
-}

demoUnit
  :: forall html
   . Html html
  => DataUI' html _ _ Unit
demoUnit =
  ID.unit_

{-

<!-- START embed unit 250 -->
<!-- END embed -->

-}