module BlastItWithPiss
    (ShSettings(..)
    ,MuSettings(..)
    ,CaptchaType(..)
    ,CaptchaAnswer(..)
    ,OriginStamp(..)
    ,renderCompactStamp
    ,Message(..)
    ,OutMessage(..)
    ,LogDetail(..)
    ,ProxySettings(..)
    ,defMuS
    ,defPrS
    ,entryPoint
    ,sortSsachBoardsByPopularity
    ) where
import Import
import BlastItWithPiss.Blast
import BlastItWithPiss.Image
import BlastItWithPiss.Board
import BlastItWithPiss.Parsing
import BlastItWithPiss.Choice
import BlastItWithPiss.MonadChoice
import BlastItWithPiss.MultipartFormData
import BlastItWithPiss.Post
import Control.Concurrent.Lifted
import Control.Concurrent.STM
import Control.Monad.Trans.Class
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State.Strict
import qualified Text.Show as Show
import Text.HTML.TagSoup(Tag)

{-
import Control.Concurrent (forkIO)
import GHC.Conc (threadStatus, ThreadStatus(..))
import System.Process
import System.Exit
import Network
import qualified Data.ByteString.Lazy as L
--}

data ShSettings = ShSettings {tpastagen :: TVar ((Int -> IO Thread) -> Maybe Page -> Maybe Int -> IO ((Bool, Bool), String))
                             ,timages :: TVar [FilePath]
                             ,tuseimages :: TVar Bool
                             ,tappendjunkimages :: TVar Bool
                             ,tcreatethreads :: TVar Bool
                             ,tmakewatermark :: TVar Bool
                             }

data MuSettings = MuSettings {mthread :: TVar (Maybe Int)
                             ,mmode :: TVar (Maybe Mode)
                             }

data CaptchaType = CaptchaPosting | CaptchaCloudflare

data CaptchaAnswer = Answer !String !(OriginStamp -> IO ())
                   | ReloadCaptcha
                   | AbortCaptcha

data OriginStamp = OriginStamp {oTime :: !POSIXTime
                               ,oProxy :: !BlastProxy
                               ,oBoard :: !Board
                               ,oMode :: !Mode
                               ,oThread :: !(Maybe Int)
                               }

data Message = OutcomeMessage !Outcome
             | LogMessage !String
             | SupplyCaptcha {captchaType :: !CaptchaType
                             ,captchaBytes :: !LByteString
                             ,captchaSend :: !(CaptchaAnswer -> IO ())
                             }
             | NoPastas
             | NoImages

data OutMessage = OutMessage !OriginStamp !Message

data LogDetail = Log
               | Don'tLog
    deriving (Eq, Show, Ord, Enum, Bounded)

data ProxySettings = ProxyS {psharedCookies :: !(TMVar CookieJar)
                            ,pcloudflareCaptchaLock :: !(TMVar ())
                            }

data BlastLogData = BlastLogData
        {bldProxy :: !BlastProxy
        ,bldBoard :: !Board
        ,bldLogD :: !LogDetail
        ,bldShS :: !ShSettings
        ,bldMuS :: !MuSettings
        ,bldPrS :: !ProxySettings
        ,bldOut :: !(OutMessage -> IO ())
        }

data OriginInfo = OriginInfo {gmode :: !Mode, gthread :: !(Maybe Int)}

type BlastLog = ReaderT BlastLogData (StateT OriginInfo Blast)

instance Show OriginStamp where
    show (OriginStamp time proxy board mode thread) =
        "(" ++ show time ++ ") " ++ "{" ++ show proxy ++ "} " ++ renderBoard board ++
        " " ++ show mode ++ " [| " ++
        ssachThread board thread ++ " |]"

renderCompactStamp :: OriginStamp -> String
renderCompactStamp (OriginStamp _ proxy board _ _) =
    renderBoard board ++ " {" ++ show proxy ++ "}"

instance Show Message where
    show (OutcomeMessage o) = show o
    show (LogMessage o) = o
    show SupplyCaptcha{} = "SupplyCaptcha"
    show NoPastas = "NoPastas"
    show NoImages = "NoImages"

instance Show CaptchaAnswer where
    show (Answer a _) = "Answer " ++ show a ++ " <repBad>"
    show ReloadCaptcha = "ReloadCaptcha"
    show AbortCaptcha = "AbortCaptcha"

instance Show OutMessage where
    show (OutMessage s m) = show s ++ ": " ++ show m

instance Default OriginInfo where
    def = OriginInfo CreateNew Nothing

instance NFData CaptchaType

instance NFData CaptchaAnswer where
    rnf (Answer s r) = r `seq` rnf s
    rnf ReloadCaptcha = ()
    rnf AbortCaptcha = ()

instance NFData OriginStamp where
    rnf (OriginStamp t p b m th) = rnf (t,p,b,m,th)

instance NFData Message where
    rnf (OutcomeMessage o) = rnf o
    rnf (LogMessage s) = rnf s
    rnf (SupplyCaptcha c b s) = rnf (c, b) `deepseq` s `seq` ()
    rnf NoPastas = ()
    rnf NoImages = ()

instance NFData OutMessage where
    rnf (OutMessage os m) = os `deepseq` m `deepseq` ()

instance MonadRandom m => MonadRandom (StateT s m) where
    getRandom = lift getRandom
    getRandoms = lift getRandoms
    getRandomR = lift . getRandomR
    getRandomRs = lift . getRandomRs

flMaybeSTM :: MonadIO m => TVar (Maybe a) -> (a -> m b) -> m b -> m b
flMaybeSTM t d m = maybe m d =<< liftIO (readTVarIO t)

flBoolModSTM :: MonadIO m => TVar Bool -> (a -> m a) -> a -> m a
flBoolModSTM t f v = ifM (liftIO $ readTVarIO t) (f v) (return v)

defMuS :: IO MuSettings
defMuS = atomically $ do
    mthread <- newTVar Nothing
    mmode <- newTVar Nothing
    return MuSettings{..}

defPrS :: IO ProxySettings
defPrS = atomically $ do
    psharedCookies <- newEmptyTMVar
    pcloudflareCaptchaLock <- newTMVar ()
    return ProxyS{..}

runBlastLog :: BlastLogData -> BlastLog a -> Blast a
runBlastLog d m = evalStateT (runReaderT m d) def

runBlastLogSt :: BlastLogData -> OriginInfo -> BlastLog a -> Blast a
runBlastLogSt d o m = evalStateT (runReaderT m d) o

askProxy :: BlastLog BlastProxy
askProxy = asks bldProxy

askBoard :: BlastLog Board
askBoard = asks bldBoard

askLogD :: BlastLog LogDetail
askLogD = asks bldLogD

askOrI :: BlastLog OriginInfo
askOrI = lift get

askShS :: BlastLog ShSettings
askShS = asks bldShS

askBSM :: BlastLog (Board, ShSettings, MuSettings)
askBSM = asks $ \b -> (bldBoard b, bldShS b, bldMuS b)

askProxyS :: BlastLog ProxySettings
askProxyS = asks bldPrS

askOut :: BlastLog (OutMessage -> IO ())
askOut = asks bldOut

recMode :: Mode -> BlastLog ()
recMode m = lift get >>= \s -> lift $ put s{gmode=m}

recThread :: (Maybe Int) -> BlastLog ()
recThread t = lift get >>= \s -> lift $ put s{gthread=t}

genOriginStamp :: BlastLog OriginStamp
genOriginStamp = do
    proxy <- askProxy
    board <- askBoard
    OriginInfo{..} <- askOrI
    now <- liftIO getPOSIXTime
    return $ OriginStamp now proxy board gmode gthread

blastOut :: Message -> BlastLog ()
blastOut msg = do
    to <- askOut
    st <- genOriginStamp
    let a = OutMessage st msg
    liftIO $ a `deepseq` to a

blastLog :: String -> BlastLog ()
blastLog msg = do
    d <- askLogD
    when (d == Log) $ do
        blastOut (LogMessage msg)

blast :: Blast a -> BlastLog a
blast = lift . lift

blastImage :: Mode -> BlastLog (Maybe Image)
blastImage mode = do
    ShSettings{..} <- askShS
    use <- liftIO $ readTVarIO tuseimages
    if not use && mode /= CreateNew || mode == SagePopular
        then
            return Nothing
        else do
            images <- liftIO $ if use then readTVarIO timages else return []
            if null images
                then do
                    blastOut NoImages
                    blastLog "threw NoImages"
                    -- use recaptcha as a fallback
                    Just . Image "haruhi.jpg" "image/jpeg" <$> blast
                            (getCaptchaImage =<<
                                    getChallengeKey ssachRecaptchaKey)
                else do
                    file <- chooseFromList images
                    blastLog $ "chose image \"" ++ file ++ "\""
                    Just <$> readImageWithoutJunk file

blastPasta :: (Int -> BlastLog Thread) -> Maybe Page -> Maybe Int -> BlastLog ((Bool, Bool), String)
blastPasta getThread p0 tid = do
    ShSettings{..} <- askShS
    pastagen <- liftIO $ readTVarIO tpastagen
    r <- ask
    s <- lift get
    liftIO $ pastagen (runBlast . runBlastLogSt r s . getThread) p0 tid

blastCaptcha :: String -> Maybe Int -> BlastLog (String, Maybe (String, (OriginStamp -> IO ())))
blastCaptcha wakabapl thread = do
    board <- askBoard
    chKey <- blast $ getChallengeKey ssachRecaptchaKey
    mbbytes <- blast $ ssachGetCaptcha board thread ssachRecaptchaKey chKey
    case mbbytes of
        Nothing -> return (chKey, Just ("", const $ return ()))
        Just bytes -> do
            m <- newEmptyMVar
            blastOut $ SupplyCaptcha CaptchaPosting bytes (putMVar m $!!)
            blastLog "blocking on captcha mvar"
            a <- takeMVar m
            blastLog "got captcha mvar"
            case a of
                Answer s r -> return (chKey, Just (s, r))
                ReloadCaptcha -> blastCaptcha wakabapl thread
                AbortCaptcha -> return (chKey, Nothing)

-- TODO Should be buggy as hell.
blastCloudflare :: BlastLog (Response [Tag Text]) -> String -> BlastLog (Response [Tag Text])
blastCloudflare whatrsp url = blastCloudflare' =<< whatrsp
  where blastCloudflare' rsp
            | responseStatus rsp == status403 && cloudflareBan (responseBody rsp) =
                return rsp -- oyoyoyoy
            | responseStatus rsp == status403 && cloudflareCaptcha (responseBody rsp) =
                cloudflareChallenge
            | otherwise = return rsp
        cloudflareChallenge = do
            blastLog "Encountered cloudflare challenge"
            ProxyS{..} <- askProxyS
            (empt, work) <- liftIO $ atomically $ do
                empt <- isEmptyTMVar psharedCookies
                work <- isEmptyTMVar pcloudflareCaptchaLock
                when (empt && not work) $
                    takeTMVar pcloudflareCaptchaLock
                return (empt, work)
            if not empt || work
                then do
                    blastLog "Waiting for cloudflare cookies..."
                    void $ liftIO $ atomically $ readTMVar pcloudflareCaptchaLock
                    nothingyet <- liftIO $ atomically $ isEmptyTMVar psharedCookies
                    if nothingyet
                        then cloudflareChallenge
                        else do blastLog "Got cloudflare cookies"
                                blast $ setCookieJar =<< liftIO (atomically $ readTMVar psharedCookies)
                                whatrsp
                else handle (\(a::SomeException) -> do
                                liftIO $ atomically $ putTMVar pcloudflareCaptchaLock ()
                                throwIO a) $ do
                    blastLog "locked cloudflare captcha"
                    chKey <- blast $ getChallengeKey cloudflareRecaptchaKey
                    bytes <- blast $ getCaptchaImage chKey
                    m <- newEmptyMVar
                    -- FIXME wait, why the hell don't we use blastCaptcha?
                    blastOut $ SupplyCaptcha CaptchaCloudflare bytes (putMVar m $!!)
                    a <- takeMVar m
                    case a of
                        Answer s _ -> do
                            let rq = urlEncodedBody
                                    [("recaptcha_challenge_key", fromString chKey)
                                    ,("recaptcha_response_key", fromString s)
                                    ,("message", "")
                                    ,("act", "captcha")
                                    ] $ (fromJust $ parseUrl url)
                                        {checkStatus = \_ _ -> Nothing
                                        ,redirectCount = 0}
                            void $ blast $ httpReq rq
                            ck <- blast $ getCookieJar
                            let ckl = length $ destroyCookieJar ck
                            if ckl==0
                                then do blastLog "Couldn't get Cloudflare cookies. Retrying."
                                        liftIO $ atomically $ putTMVar pcloudflareCaptchaLock ()
                                        blastCloudflare whatrsp url
                                else do blastLog $ "Cloudflare cookie count: " ++ show (length $ destroyCookieJar ck)
                                        liftIO $ atomically $ do
                                            putTMVar pcloudflareCaptchaLock ()
                                            putTMVar psharedCookies ck
                                        blastLog "finished working on captcha"
                                        whatrsp
                        ReloadCaptcha -> cloudflareChallenge
                        AbortCaptcha -> do
                            blastLog "Aborting cloudflare captcha. This might have unforeseen consequences."
                            liftIO $ atomically $ do
                                putTMVar pcloudflareCaptchaLock ()
                            whatrsp

blastPost :: Bool -> POSIXTime -> POSIXTime -> (String, [Field]) -> Mode -> Maybe Int -> PostData -> BlastLog (POSIXTime, POSIXTime)
blastPost cap lthreadtime lposttime w@(wakabapl, otherfields) mode thread postdata = do
    (board, ShSettings{..}, _) <- askBSM
    (chKey, mcap) <- if cap || mode==CreateNew || not ssachAdaptivity
                        then do blastLog "querying captcha"
                                blastCaptcha wakabapl thread
                        else do blastLog "skipping captcha"
                                return ("", Just ("", const $ return ()))
    case mcap of
        Nothing -> return (lthreadtime, lposttime)
        Just (captcha, reportbad) -> do
            -- TODO post reposts
            p <- blast $ prepare board thread postdata chKey captcha wakabapl
                                 otherfields ssachLengthLimit
            beforeSleep <- liftIO getPOSIXTime
            let canPost = beforeSleep - lposttime >= ssachPostTimeout board
            when (mode /= CreateNew && not canPost) $ do
                let slptime = (lposttime + ssachPostTimeout board) - beforeSleep
                blastLog $ "sleeping " ++ show slptime ++ " seconds before post. FIXME using threadDelay for sleeping, instead of a more precise timer"
                liftIO $ threadDelay $ round $ slptime * 1000000
            blastLog "posting"
            beforePost <- liftIO $ getPOSIXTime
            (out, _) <- blast $ post p
            -- FIXME afterPost <- liftIO $ getPOSIXTime
            blastOut (OutcomeMessage out)
            when (successOutcome out) $ blastLog "post succeded"
            let (nthreadtime, nposttime) =
                    if mode == CreateNew
                        then (beforePost, lposttime)
                        else (lthreadtime, beforePost)
                ret = return (nthreadtime, nposttime)
            case out of
                Success -> ret
                SuccessLongPost rest ->
                    if mode /= CreateNew
                        then blastPost cap nthreadtime nposttime w mode thread
                                (PostData "" rest Nothing (sageMode mode) False (escapeInv postdata) (escapeWrd postdata))
                        else ret
                TooFastPost -> do
                        blastLog "TooFastPost, retrying in 0.5 seconds"
                        return (lthreadtime, beforePost - (ssachPostTimeout board - 0.5))
                TooFastThread -> do
                        blastLog "TooFastThread, retrying in 15 minutes"
                        return (beforePost - (ssachThreadTimeout board / 2), lposttime)
                o | o==NeedCaptcha || o==WrongCaptcha -> do
                        blastLog $ show o ++ ", requerying"
                        liftIO . reportbad =<< genOriginStamp
                        blastPost True lthreadtime lposttime w mode thread postdata
                  | otherwise -> do
                        blastLog "post failed"
                        ret

blastLoop :: (String, [Field]) -> POSIXTime -> POSIXTime -> BlastLog ()
blastLoop w lthreadtime lposttime = do
    (board, ShSettings{..}, MuSettings{..}) <- askBSM
    let getPage p = do
            let url = ssachPage board p
            let chkStatus st@Status{statusCode=c} heads
                    | c /= 200 && c /= 403 =
                        Just $ toException $ StatusCodeException st heads
                    | otherwise =
                        Nothing
            blastLog $ "chooseThread: getPage: going to page " ++ show p
            parsePage board . responseBody <$>
                blastCloudflare (blast $ httpReqStrTags $
                    (fromJust $ parseUrl url){checkStatus=chkStatus}) url
    let getThread i = do
            blastLog $ "Going into " ++ show i ++ " thread for pasta"
            blast $ head . fst . parseThreads <$> httpGetStrTags (ssachThread board (Just i))
    now <- liftIO $ getPOSIXTime
    canmakethread <- ifM (liftIO $ readTVarIO tcreatethreads)
                        (return $ now - lthreadtime >= ssachThreadTimeout board)
                        (return False)
    mp0 <- flMaybeSTM mthread (const $ return Nothing) $ Just <$> getPage 0
    flip (maybe $ blastLog "Thread chosen, ommitting page parsing") mp0 $ \p0 ->
        blastLog $ "page params:\n" ++
                   "page id: " ++ show (pageId p0) ++ "\n" ++
                   "lastpage id: " ++ show (lastpage p0) ++ "\n" ++
                   "speed: " ++ show (speed p0) ++ "\n" ++
                   "threads: " ++ show (length $ threads p0) ++ "\n" ++
                   "max replies: " ++ show (maximum $ map postcount $ threads p0)
    mode <- flMaybeSTM mmode return $
        maybe (do blastLog "No page, choosing from SagePopular/BumpUnpopular"
                  chooseFromList [SagePopular, BumpUnpopular])
              (\p0 -> do blastLog "Parsing page to decide mode..."
                         chooseMode board canmakethread p0) mp0
    recMode mode
    blastLog $ "chose mode " ++ show mode
    (thread, mpastapage) <- flMaybeSTM mthread (\t -> return (Just t, Nothing)) $
        appsnd Just <$> chooseThread mode getPage
            (fromMaybe (error "Page is Nothing while thread specified") mp0)
    recThread thread
    blastLog $ "chose thread " ++ show thread
    ((escinv, escwrd), pasta) <- blastPasta getThread mpastapage thread
    blastLog $ "chose pasta, escaping invisibles " ++ show escinv ++
        ", escaping wordfilter " ++ show escwrd ++ ": \"" ++ pasta ++ "\""
    cleanImage <- blastImage mode
    junkImage <- case cleanImage of
        Nothing -> return Nothing
        Just i -> Just <$> flBoolModSTM tappendjunkimages
            (\im -> do blastLog "appending junk to image"
                       appendJunk im) i
    watermark <- liftIO $ readTVarIO tmakewatermark
    (nthreadtime, nposttime) <- blastPost False lthreadtime lposttime w mode thread
            (PostData "" pasta junkImage (sageMode mode) watermark escinv escwrd)
    blastLoop w nthreadtime nposttime

-- | Entry point should always be forked.
--
-- > thread <- forkIO (entryPoint print sh to Board ms)
--
-- You might want to resurrect thread if it dies.
--
-- > st <- threadStatus thread
-- > if st==ThreadDied || st==ThreadFinished
-- >    then resurrect
-- >    else continue
entryPoint :: BlastProxy -> Board -> LogDetail -> ShSettings -> MuSettings -> ProxySettings -> (OutMessage -> IO ()) -> Blast ()
entryPoint proxy board lgDetail shS muS prS output = do
    runBlastLog (BlastLogData proxy board lgDetail shS muS prS output) $ do
        blastLog "Entry point"
        blast $ httpSetProxy proxy
        let hands =
              [Handler $ \(a::AsyncException) -> throwIO a
              ,Handler $ \(a::HttpException) -> do
                blastLog $ "Got http exception, restarting. Exception was: " ++ show a
                start -- Dunno what to do except restart.
              ,Handler $ \(a::SomeException) -> do
                blastLog $ "Terminated by exception " ++ show a
                blastOut $ OutcomeMessage $ InternalError $ ErrorException a
              ]
            start = flip catches hands $
                blastLoop (ssachLastRecordedWakabaplAndFields (ssachBoard board)) 0 0
        start{-
        let url = ssachBoard board
        let chkStatus st@Status{statusCode=c} heads
                | c /= 200 && c /= 403 = Just $ toException $ StatusCodeException st heads Nothing
                | otherwise = Nothing
        x <- try $ do
            blastLog $ "Downloading page form"
            {-
            rsp <- blast $ httpReqStrTags (fromJust $ parseUrl url){checkStatus=chkStatus}
            parseForm ssach <$> blastCloudflare (blast $ httpGetStrTags url) url rsp
            -}
            {-
            blast $ lift . conduitParseForm ssach . responseBody =<< makeRequest (fromJust $ parseUrl url)
            -}
            return $ ssachLastRecordedWakabaplAndFields url
        case x of
            Left (a::SomeException) -> do
                blastLog $ "Couldn't parse page form, got exception " ++ show a
            Right w -> do
                blastLog "Starting loop"
                --blastLog $ show $ length $ (show w :: String)
                --forever (return () >> liftIO yield)
                blastLoop w 0 0-}

sortSsachBoardsByPopularity :: [Board] -> IO ([(Board, Int)], [Board])
sortSsachBoardsByPopularity boards = runBlast $ do
    maybeb <- forM boards $ \b -> do
                liftIO $ putStr $ "Processing " ++ renderBoard b ++ ". Speed: "
                spd <- parseSpeed <$> httpGetStrTags (ssachBoard b)
                liftIO $ putStrLn $ show spd
                return (b, spd)
    let (got, failed) = partition (isJust . snd) maybeb
        sorted = reverse $ sortBy (\(_,a) (_,b) -> compare (fromJust a) (fromJust b)) got
    return (map (appsnd fromJust) sorted, fst $ unzip $ failed)
