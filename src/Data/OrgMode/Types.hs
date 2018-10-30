{-|
Module      :  Data.OrgMode.Types
Copyright   :  © 2014 Parnell Springmeyer
License     :  All Rights Reserved
Maintainer  :  Parnell Springmeyer <parnell@digitalmentat.com>
Stability   :  experimental

Types for the AST of an org-mode document.
-}

{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}

{-# OPTIONS -fno-warn-orphans           #-}

module Data.OrgMode.Types
( ActiveState       (..)
, BracketedDateTime (..)
, Clock             (..)
, DateTime          (..)
, Delay             (..)
, DelayType         (..)
, Depth             (..)
, Document          (..)
, Drawer
, Duration
, Headline          (..)
, Logbook           (..)
, PlanningKeyword   (..)
, Plannings         (..)
, Priority          (..)
, Properties        (..)
, Repeater          (..)
, RepeaterType      (..)
, Section           (..)
, StateKeyword      (..)
, Stats             (..)
, Tag
, TimePart          (..)
, TimeUnit          (..)
, Timestamp         (..)
, YearMonthDay      (..)
, Block             (..)
, MarkupText        (..)
, Item              (..)
, sectionDrawer
) where

import           Control.Monad                     (mzero)
import           Data.Aeson                        ((.:), (.=))
import qualified Data.Aeson                        as Aeson
import           Data.Hashable                     (Hashable (..))
import           Data.HashMap.Strict               (HashMap, fromList, keys, toList)
import           Data.Text                         (Text, pack)
import           Data.Thyme.Calendar               (YearMonthDay (..))
import           Data.Thyme.LocalTime              (Hour, Hours, Minute, Minutes)
import           GHC.Generics
import           Data.Semigroup                    (Semigroup)

-- | Org-mode document.
data Document = Document
  { documentText      :: Text       -- ^ Text occurring before any Org headlines
  , documentHeadlines :: [Headline] -- ^ Toplevel Org headlines
  } deriving (Show, Eq, Generic)

instance Aeson.ToJSON Document
instance Aeson.FromJSON Document

-- | Headline within an org-mode document.
data Headline = Headline
  { depth        :: Depth              -- ^ Org headline nesting depth (1 is at the top), e.g: * or ** or ***
  , stateKeyword :: Maybe StateKeyword -- ^ State of the headline, e.g: TODO, DONE
  , priority     :: Maybe Priority     -- ^ Headline priority, e.g: [#A]
  , title        :: Text               -- ^ Primary text of the headline
  , timestamp    :: Maybe Timestamp    -- ^ A timestamp that may be embedded in the headline
  , stats        :: Maybe Stats        -- ^ Fraction of subtasks completed, e.g: [33%] or [1/2]
  , tags         :: [Tag]              -- ^ Tags on the headline
  , section      :: Section            -- ^ The body underneath a headline
  , subHeadlines :: [Headline]         -- ^ A list of sub-headlines
  } deriving (Show, Eq, Generic)

-- | Headline nesting depth.
newtype Depth = Depth Int
  deriving (Eq, Show, Num, Generic)

instance Aeson.ToJSON Depth
instance Aeson.FromJSON Depth


-- | Section of text directly following a headline.
data Section = Section
  { sectionTimestamp  :: Maybe Timestamp -- ^ A headline's section timestamp
  , sectionPlannings  :: Plannings       -- ^ A map of planning timestamps
  , sectionClocks     :: [Clock]         -- ^ A list of clocks
  , sectionProperties :: Properties      -- ^ A map of properties from the :PROPERTY: drawer
  , sectionLogbook    :: Logbook         -- ^ A list of clocks from the :LOGBOOK: drawer
  , sectionBlocks     :: [Block]  -- ^ Content of Section
  } deriving (Show, Eq, Generic)

sectionDrawer :: Section -> [Block]
sectionDrawer s = foldr getDrawer [] (sectionBlocks s) where
  getDrawer x drawers = case x of Drawer _ _ -> x:drawers
                                  _ -> drawers

newtype Properties = Properties { unProperties :: HashMap Text Text }
  deriving (Show, Eq, Generic, Semigroup, Monoid)

data MarkupText = Plain Text | LaTeX Text | Bold [MarkupText] | Italic [MarkupText] | UnderLine [MarkupText] deriving (Show, Eq, Generic)

newtype Item = Item [Block] deriving (Show, Eq, Generic, Semigroup, Monoid)

data Block = OrderedList [Item] | UnorderedList [Item] | Paragraph [MarkupText] | Drawer {
    name     :: Text
  , contents :: Text
} deriving (Show, Eq, Generic)
type Drawer = Block

instance Aeson.ToJSON MarkupText
instance Aeson.FromJSON MarkupText

instance Aeson.ToJSON Item
instance Aeson.FromJSON Item

instance Aeson.ToJSON Block
instance Aeson.FromJSON Block

instance Aeson.ToJSON Properties
instance Aeson.FromJSON Properties

newtype Logbook = Logbook { unLogbook :: [Clock] }
  deriving (Show, Eq, Generic, Semigroup, Monoid)


instance Aeson.ToJSON Logbook
instance Aeson.FromJSON Logbook

-- | Sum type indicating the active state of a timestamp.
data ActiveState
  = Active
  | Inactive
  deriving (Show, Eq, Read, Generic)

instance Aeson.ToJSON ActiveState
instance Aeson.FromJSON ActiveState

newtype Clock = Clock { unClock :: (Maybe Timestamp, Maybe Duration) }
  deriving (Show, Eq, Generic)

instance Aeson.ToJSON Clock
instance Aeson.FromJSON Clock

-- | A generic data type for parsed org-mode time stamps, e.g:
--
-- > <2015-03-27 Fri 10:20>
-- > [2015-03-27 Fri 10:20 +4h]
-- > <2015-03-27 Fri 10:20>--<2015-03-28 Sat 10:20>
data Timestamp = Timestamp
  { tsTime    :: DateTime       -- ^ A datetime stamp
  , tsActive  :: ActiveState    -- ^ Active or inactive?
  , tsEndTime :: Maybe DateTime -- ^ A end-of-range datetime stamp
  } deriving (Show, Eq, Generic)

instance Aeson.ToJSON Timestamp
instance Aeson.FromJSON Timestamp

instance Aeson.ToJSON YearMonthDay where
  toJSON (YearMonthDay y m d) =
    Aeson.object
      [ "ymdYear"  .= y
      , "ymdMonth" .= m
      , "ymdDay"   .= d
      ]

instance Aeson.FromJSON YearMonthDay where
  parseJSON (Aeson.Object v) = do
    y <- v .: "ymdYear"
    m <- v .: "ymdMonth"
    d <- v .: "ymdDay"
    pure (YearMonthDay y m d)
  parseJSON _ = mzero


type Weekday = Text
type AbsTime = (Hours, Minutes)

-- | A data type for parsed org-mode bracketed datetime stamps, e.g:
--
-- > [2015-03-27 Fri 10:20 +4h]
data BracketedDateTime = BracketedDateTime
  { datePart    :: YearMonthDay
  , dayNamePart :: Maybe Weekday
  , timePart    :: Maybe TimePart
  , repeat      :: Maybe Repeater
  , delayPart   :: Maybe Delay
  , activeState :: ActiveState
  } deriving (Show, Eq)

-- | A sum type representing an absolute time part of a bracketed
-- org-mode datetime stamp or a time range between two absolute
-- timestamps.
data TimePart
  = AbsoluteTime   AbsTime
  | TimeStampRange (AbsTime, AbsTime)
  deriving (Eq, Ord, Show)

-- | A data type for parsed org-mode datetime stamps.
--
-- TODO: why do we have this data type and BracketedDateTime? They
-- look almost exactly the same...
data DateTime = DateTime {
    yearMonthDay :: YearMonthDay
  , dayName      :: Maybe Text
  , hourMinute   :: Maybe (Hour,Minute)
  , repeater     :: Maybe Repeater
  , delay        :: Maybe Delay
  } deriving (Show, Eq, Generic)

instance Aeson.ToJSON DateTime
instance Aeson.FromJSON DateTime

-- | A sum type representing the repeater type of a repeater interval
-- in a org-mode timestamp.
data RepeaterType
  = RepeatCumulate
  | RepeatCatchUp
  | RepeatRestart
  deriving (Show, Eq, Generic)

instance Aeson.ToJSON RepeaterType
instance Aeson.FromJSON RepeaterType

-- | A data type representing a repeater interval in a org-mode
-- timestamp.
data Repeater = Repeater
  { repeaterType  :: RepeaterType -- ^ Type of repeater
  , repeaterValue :: Int          -- ^ Repeat value
  , repeaterUnit  :: TimeUnit     -- ^ Repeat time unit
  } deriving (Show, Eq, Generic)

instance Aeson.ToJSON Repeater
instance Aeson.FromJSON Repeater

-- | A sum type representing the delay type of a delay value.
data DelayType
  = DelayAll
  | DelayFirst
  deriving (Show, Eq, Generic)

instance Aeson.ToJSON DelayType
instance Aeson.FromJSON DelayType

-- | A data type representing a delay value.
data Delay = Delay
  { delayType  :: DelayType -- ^ Type of delay
  , delayValue :: Int       -- ^ Delay value
  , delayUnit  :: TimeUnit  -- ^ Delay time unit
  } deriving (Show, Eq, Generic)

instance Aeson.ToJSON Delay
instance Aeson.FromJSON Delay

-- | A sum type representing the time units of a delay.
data TimeUnit
  = UnitYear
  | UnitWeek
  | UnitMonth
  | UnitDay
  | UnitHour
  deriving (Show, Eq, Generic)

instance Aeson.ToJSON TimeUnit
instance Aeson.FromJSON TimeUnit

-- | A type representing a headline state keyword, e.g: @TODO@,
-- @DONE@, @WAITING@, etc.
newtype StateKeyword = StateKeyword {unStateKeyword :: Text}
  deriving (Show, Eq, Generic)

instance Aeson.ToJSON StateKeyword
instance Aeson.FromJSON StateKeyword

-- | A sum type representing the planning keywords.
data PlanningKeyword = SCHEDULED | DEADLINE | CLOSED
  deriving (Show, Eq, Enum, Ord, Generic)

instance Aeson.ToJSON PlanningKeyword
instance Aeson.FromJSON PlanningKeyword

-- | A type representing a map of planning timestamps.
newtype Plannings = Plns (HashMap PlanningKeyword Timestamp)
                  deriving (Show, Eq, Generic)

instance Aeson.ToJSON Plannings where
  toJSON (Plns hm) = Aeson.object $ map jPair (toList hm)
    where jPair (k, v) = pack (show k) .= Aeson.toJSON v

instance Aeson.FromJSON Plannings where
  parseJSON (Aeson.Object v) = Plns . fromList <$> traverse jPair (keys v)
    where jPair k = v .: k
  parseJSON _ = mzero

instance Aeson.ToJSON Section
instance Aeson.FromJSON Section

instance Aeson.ToJSON Headline
instance Aeson.FromJSON Headline

-- | A sum type representing the three default priorities: @A@, @B@,
-- and @C@.
data Priority = A | B | C
  deriving (Show, Read, Eq, Ord, Generic)

instance Aeson.ToJSON Priority
instance Aeson.FromJSON Priority
type Tag = Text

-- | A data type representing a stats value in a headline, e.g @[2/3]@
-- in this headline:
--
-- > * TODO [2/3] work on orgmode-parse
data Stats = StatsPct Int
           | StatsOf  Int Int
           deriving (Show, Eq, Generic)

instance Aeson.ToJSON Stats
instance Aeson.FromJSON Stats

type Duration = (Hour,Minute)

instance Hashable PlanningKeyword where
  hashWithSalt salt k = hashWithSalt salt (fromEnum k)

