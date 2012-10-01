{-# LANGUAGE NoImplicitPrelude #-}
module GtkBlast.Maintenance
    (maintainWipeUnit
    ,regenerateExcluding
    ,maintainBoardUnit
    ,maintainBoardUnits
    ,startWipe
    ,killWipe
    ,setBanned
    ,reactToMessage
    ) where
import Import hiding (on)
import GtkBlast.IO
import GtkBlast.MuVar
import GtkBlast.Environment
import GtkBlast.Log
import GtkBlast.GuiCaptcha
import "blast-it-with-piss" BlastItWithPiss
import "blast-it-with-piss" BlastItWithPiss.Blast
import "blast-it-with-piss" BlastItWithPiss.Post
import "blast-it-with-piss" BlastItWithPiss.Board
import GHC.Conc
import qualified Data.Map as M
import Control.Monad.Trans.Maybe

maintainWipeUnit :: BoardUnit -> Bool -> Bool -> WipeUnit -> E (Maybe WipeUnit)
maintainWipeUnit BoardUnit{..} isActive isWiping w@WipeUnit{..} = do
        E{..} <- ask
        st <- io $ threadStatus wuThreadId
        isBanned <- get wuBanned
        pxs <- M.keys <$> get proxies
        if st == ThreadDied || st == ThreadFinished
            then do
                writeLog $ "blasgtk: Thread for {" ++ show wuProxy ++ "} " ++ renderBoard buBoard ++ " died. Removing"
                return Nothing
            else if not isActive || not isWiping || isBanned || notElem wuProxy pxs
                    then do
                        writeLog $ "blasgtk: Killing thread for " ++ renderBoard buBoard
                        io $ killThread wuThreadId
                        return Nothing -- TODO don't regenerate banned threads
                    else return $ Just w

regenerateExcluding :: Board -> [WipeUnit] -> E [WipeUnit]
regenerateExcluding board exc = do
    E{..} <- ask
    prx <- M.assocs <$> get proxies
    catMaybes <$> forM prx (\(p, s) ->
        if any ((==p) . wuProxy) exc
            then return Nothing
            else do writeLog $ "Spawning new thread for " ++ renderBoard board
                    mthread <- io $ atomically $ newTVar Nothing
                    mmode <- io $ atomically $ newTVar Nothing
                    threadid <- io $ forkIO $ runBlast $ do
                        entryPoint board p Log shS MuSettings{..} s tqOut
                    Just . WipeUnit p threadid <$> io (newIORef False)
        )
    
maintainBoardUnit :: (Int, Int) -> BoardUnit -> E (Int, Int)
maintainBoardUnit (active, banned) bu@BoardUnit{..} = do
    E{..} <- ask
    isActive <- get buWidget
    isWiping <- get wipeStarted
    new <- catMaybes <$> (mapM (maintainWipeUnit bu isActive isWiping) =<< (get buWipeUnits))
    regend <- if isActive && isWiping
                then regenerateExcluding buBoard new
                else return []
    set buWipeUnits $ new ++ regend
    isBanned <- --FIXME FIXME FIXME readIORef buBanned
                return False
    return (active + (if isActive then 1 else 0)
           ,banned + (if isBanned then 1 else 0))

maintainBoardUnits :: E ()
maintainBoardUnits = do
    E{..} <- ask
    (active, banned) <- foldM maintainBoardUnit (0,0) boardUnits
    set activeCount active
    set bannedCount banned

startWipe :: E ()    
startWipe = do
    E{..} <- ask
    set wipeStarted True
    maintainBoardUnits

killWipe :: E ()
killWipe = do
    E{..} <- ask
    writeLog "Stopping wipe..."
    set wipeStarted False
    maintainBoardUnits
    pc <- get pendingCaptchas
    forM_ pc $ const $ removeCaptcha AbortCaptcha

setBanned :: [BoardUnit] -> Board -> BlastProxy -> Bool -> IO ()
setBanned boardUnits board proxy st = do
        maybe (return ()) ((`writeIORef` st) . wuBanned) =<< runMaybeT (do
            ws <- maybe mzero (liftIO . readIORef . buWipeUnits) $
                    find ((==board) . buBoard) boardUnits
            maybe mzero return $ find ((==proxy) . wuProxy) ws)

reactToMessage :: OutMessage -> E ()
reactToMessage s@(OutMessage st@(OriginStamp _ proxy board _ _) m) = do
    E{..} <- ask
    case m of
        OutcomeMessage o -> do
            case o of
                SuccessLongPost _ -> writeLog (show st ++ ": SuccessLongPost")
                _ -> writeLog (show s)
            case o of
                Success -> do
                    io $ modifyIORef postCount (+1)
                    io $ setBanned boardUnits board proxy False
                SuccessLongPost _ -> io $ modifyIORef postCount (+1)
                Wordfilter -> tempError 3 "Не удалось обойти вордфильтр"
                Banned x -> do
                    banMessage 5 $ "Забанен на доске " ++ renderBoard board
                                ++ " Причина: " ++ show x
                                ++ "\nВозможно стоит переподключится или начать вайпать /d/"
                    io $ setBanned boardUnits board proxy True
                SameMessage -> tempError 2 $ renderBoard board ++ ": Запостил одно и то же сообщение"
                SameImage -> tempError 2 $ renderBoard board ++ ": Запостил одну и ту же пикчу"
                TooFastPost -> return () -- tempError 2 $ renderBoard board ++ ": Вы постите слишком часто, умерьте пыл"
                TooFastThread -> tempError 3 $ renderBoard board ++ ": Вы создаете треды слишком часто"
                NeedCaptcha -> return ()
                WrongCaptcha -> tempError 3 "Неправильно введена капча"
                RecaptchaBan -> do
                    banMessage 7 $ "Забанен рекапчой, охуеть. Переподключайся, мудило"
                    io $ setBanned boardUnits board proxy True
                LongPost -> tempError 1 $ renderBoard board ++ ": Запостил слишком длинный пост"
                CorruptedImage -> tempError 2 $ renderBoard board ++ ": Запостил поврежденное изображение"
                OtherError x -> tempError 7 $ renderBoard board ++ ": " ++ show x
                InternalError x -> tempError 7 $ renderBoard board ++ ": " ++ show x
                CloudflareCaptcha -> do
                    banMessage 7 $ "Если эта ошибка появляется то это баг, сообщите нам об этом"
                    io $ setBanned boardUnits board proxy True
                CloudflareBan -> do
                    banMessage 7 $ "Эту проксю пидорнули по клаудфлеру, она бесполезна"
                    io $ setBanned boardUnits board proxy True
                UnknownError -> tempError 4 $ renderBoard board ++ ": Неизвестная ошибка, что-то пошло не так"
        c@SupplyCaptcha{} -> addCaptcha (st, c)
        LogMessage _ -> writeLog (show s)
        NoPastas -> do writeLog (show s)
                       tempError 3 "Невозможно прочитать пасты, постим повторяющуюся строку \"NOPASTA\""
        NoImages -> do writeLog (show s)
                       tempError 3 "Невозможно прочитать пикчи, постим капчу"