--inb4 >kokoko
module BlastItWithPiss.Choice
    (
     Mode(..)
    ,Strategy
    ,sageMode
    ,obligatoryImageMode
    ,obligatoryNoImageMode
    ,unlockedSticky
    ,newThread
    ,veryPopularThread
    ,tooFast

    ,strategies
    ,defaultStrategy

    ,adjustStrategy
    ,chooseStrategy
    ,chooseModeStrategy
    ,chooseThread'

    ,chooseMode
    ,chooseThread
    ) where
import Import hiding ((/))

import BlastItWithPiss.Board
import BlastItWithPiss.Parsing
import BlastItWithPiss.MonadChoice

import Data.Ratio

import qualified Data.Map as M

data Mode = SagePopular
          | BumpUnpopular
          | ShitupSticky
          | BumpOld -- ^ Try to turn board upside down
          | CreateNew -- ^ Try to erase threads by creating new threads
    deriving (Eq, Show, Ord, Enum, Bounded)

type Strategy = [(Mode, Rational)]

instance NFData Mode

sageMode :: Mode -> Bool
sageMode SagePopular = True
sageMode _ = False

obligatoryImageMode :: Mode -> Bool
obligatoryImageMode CreateNew = True
obligatoryImageMode _ = False

obligatoryNoImageMode :: Mode -> Bool
obligatoryNoImageMode SagePopular = True
obligatoryNoImageMode _ = False

infixr 0 /
(/) :: a -> b -> (a, b)
(/) = (,)

always :: Rational
always = 100000000

-- | Different strategies for different boards.
strategies :: M.Map Board Strategy
strategies =
    M.fromList $
    [SsachVG /
        [SagePopular    / 70
        ,BumpUnpopular  / 10
        ,ShitupSticky   / 50
        ,BumpOld        / 20
        ,CreateNew      / 70]
    ,SsachB /
        [SagePopular / 70
        ,BumpUnpopular / 20
        ,ShitupSticky / 50
        ,BumpOld / 10
        ,CreateNew / 200]
    ,SsachCG /
        [SagePopular / 40
        ,BumpUnpopular / 20
        ,ShitupSticky / 50
        ,BumpOld / 60
        ,CreateNew / always]
    ,SsachD /
        [SagePopular / 50
        ,BumpUnpopular / 0
        ,ShitupSticky / 50
        ,BumpOld / 30
        ,CreateNew / always]
    ,SsachMLP /
        [SagePopular / 60
        ,BumpUnpopular / 10
        ,ShitupSticky / 100
        ,BumpOld / 30
        ,CreateNew / always]
{- FIXME BB REMOVED
    ,SsachBB /
        [SagePopular / 20
        ,BumpUnpopular / 20
        ,ShitupSticky / 40
        ,BumpOld / 60
        ,CreateNew / always]
-}
    ,SsachDEV /
        [SagePopular / 15
        ,BumpUnpopular / 15
        ,ShitupSticky / 60
        ,BumpOld / 50
        ,CreateNew / always]
    ,SsachS /
        [SagePopular / 33
        ,BumpUnpopular / 33
        ,ShitupSticky / 100
        ,BumpOld / 33
        ,CreateNew / always]
    ,SsachMMO /
        [SagePopular / 50
        ,BumpUnpopular / 40
        ,ShitupSticky / 100
        ,BumpOld / 10
        ,CreateNew / always]
    ,SsachA /
        [SagePopular / 70
        ,BumpUnpopular / 20
        ,ShitupSticky / 40
        ,BumpOld / 10
        ,CreateNew / always]
    ,SsachPO /
        [SagePopular / 20
        ,BumpUnpopular / 10
        ,ShitupSticky / 40
        ,BumpOld / 30
        ,CreateNew / always]
    ,SsachSOC /
        [SagePopular / 33
        ,BumpUnpopular / 15
        ,ShitupSticky / 33
        ,BumpOld / 18
        ,CreateNew / always]
    ,SsachSEX /
        [SagePopular / 35
        ,BumpUnpopular / 45
        ,ShitupSticky / 50
        ,BumpOld / 20
        ,CreateNew / always]
    ,SsachTV /
        [SagePopular / 40
        ,BumpUnpopular / 20
        ,ShitupSticky / 60
        ,BumpOld / 20
        ,CreateNew / always]
    ,SsachFA /
        [SagePopular / 33
        ,BumpUnpopular / 15
        ,ShitupSticky / 15
        ,BumpOld / 37
        ,CreateNew / always]
    ,SsachRF /
        [SagePopular / 33
        ,BumpUnpopular / 33
        ,ShitupSticky / 60
        ,BumpOld / 34
        ,CreateNew / always]
    ,SsachD /
        [SagePopular / 10
        ,BumpUnpopular / 20
        ,ShitupSticky / 30
        ,BumpOld / 40
        ,CreateNew / always]
    ,SsachABU /
        [SagePopular / 100
        ,BumpUnpopular / 0
        ,ShitupSticky / 100
        ,BumpOld / 100
        ,CreateNew / 0]
    ]

-- | For boards not listed in "strategies"
defaultStrategy :: Strategy
defaultStrategy =
    [SagePopular    / 10
    ,BumpUnpopular  / 30
    ,ShitupSticky   / 50
    ,BumpOld        / 35
    ,CreateNew      / always]

unlocked :: Thread -> Bool
unlocked = not . locked

unpinned :: Thread -> Bool
unpinned = not . pinned

bumpable :: Board -> Thread -> Bool
bumpable board Thread{..} = postcount < ssachBumpLimit board

unlockedUnpinnedBump :: Board -> Thread -> Bool
unlockedUnpinnedBump board t = unlocked t && unpinned t && bumpable board t

unlockedSticky :: Thread -> Bool
unlockedSticky Thread{..} = not locked && pinned

newThread :: Thread -> Bool
newThread t = postcount t <= 5

veryPopularThread :: Thread -> Bool
veryPopularThread t = postcount t >= 100

tooFast :: Int -> Bool
tooFast s = s >= 200

-- | We take a look at the front page, and adjust our strategy depending on what we see.
adjustStrategy :: Strategy -> Bool -> Bool -> Page -> Strategy
adjustStrategy strategy canmakethread sage Page{..}
    -- >kokoko
    | !len <- fromIntegral $ length threads
    , if len /= 0
        then True
        else error "adjustStrategy: no threads found"
    , !new <- fromIntegral (length $ filter newThread threads) % len
    , !vpop <- fromIntegral (length $ filter veryPopularThread threads) % len
    , !nps <- if tooFast speed
                then [CreateNew, BumpUnpopular]
                else [BumpOld, ShitupSticky]
    , !vps <- if tooFast speed
                then [SagePopular, ShitupSticky]
                else [BumpOld, CreateNew]
    , aux <- \(x, r) ->
                let y = r * if' (x `elem` nps) new 0
                    z = r * if' (x `elem` vps) vpop 0
                in (x, r + y + z)
    = map aux (filter goodStrategy strategy)
  where
    goodStrategy (st, _) =
        notElem st $
            [CreateNew | not canmakethread] ++
            [SagePopular | not sage] ++
            [ShitupSticky | not (any unlockedSticky threads)]

chooseStrategy :: Board -> Bool -> Bool -> Page -> Strategy
chooseStrategy board =
    adjustStrategy (fromMaybe defaultStrategy (M.lookup board strategies))

chooseModeStrategy :: MonadRandom m => Strategy -> m Mode
chooseModeStrategy [] = error "chooseModeStrategy: empty list"
chooseModeStrategy a = fromList a

chooseMode :: MonadRandom m => Board -> Bool -> Bool -> Page -> m Mode
chooseMode a b c d = chooseModeStrategy $ chooseStrategy a b c d

chooseThread' :: MonadChoice m => Board -> Bool -> Mode -> Page -> m (Maybe Int)
chooseThread' _ _ CreateNew Page{..} = error "chooseThread': WTF, chooseThread with CreateNew, this should never happen"
chooseThread' board canfail mode Page{..}
    -- >kokoko
    | thrds' <- if mode == ShitupSticky
                then filter unlockedSticky threads -- we only get ShitupSticky when we KNOW there are unlocked stickies on the page
                else let nost = filter (unlockedUnpinnedBump board) threads -- we don't include stickies
                     in if null nost
                        then filter unlocked threads -- what can we do if there are only stickies left?
                        else nost
    , thrds <- if mode /= ShitupSticky && canfail
                    then (Thread (-1) False False 50 [] : thrds') -- add the possibility of failure
                                                 -- in that case we advance to the next/previous page
                    else thrds'
    , inv <- if mode == BumpUnpopular || mode == BumpOld -- these modes give more weight to unpopular threads
                then ((fromIntegral $ maximumNote "Couldn't parse threads" $ map postcount thrds) -)
                else id
     = justIf (> (-1)) <$> fromList
            (map (threadId &&& inv . fromIntegral . postcount) thrds)

chooseThread :: MonadChoice m => Board -> Mode -> (Int -> m Page) -> Page -> m (Maybe Int, Page)
chooseThread _ CreateNew _ p0 = return (Nothing, p0)
chooseThread board mode getPage p0
    | iterpages <-
        if mode==BumpOld
            then map getPage $ reverse [pageId p0 .. lastpage p0] -- traverse from end
            else (return p0 : ) $ -- traverse from beginning while not redownloading first page
                    map getPage $ tailSafe [pageId p0 .. lastpage p0]
    = untilJust $ flip findMapM iterpages $ \gp -> do
            pg <- gp
            maybe Nothing (Just . flip (,) pg . Just) <$>
                chooseThread' board True mode pg