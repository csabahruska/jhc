module Util.Perhaps where

import Data.Typeable
import Data.Monoid

import Data.Binary
import GHC.Generics (Generic)

data Perhaps = No | Maybe | Yes
    deriving(Show,Read,Typeable,Eq,Ord,Generic)

instance Binary Perhaps

-- the greatest lower bound was chosen as the Monoid
-- the least upper bound is just the maximum under Ord
instance Monoid Perhaps where
    mempty = No
    Yes `mappend` Yes = Yes
    No  `mappend` No  = No
    _   `mappend` _   = Maybe



