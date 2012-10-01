{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}
module GtkBlast.MutableConfigurableWidgets
    (interpretMuConfs
    ,mutableConfigWidgets
    ,mkAllWidgets
    ) where
import Import hiding (on, mod)
import GtkBlast.IO
import GtkBlast.MuVar
import GtkBlast.Directory
import GtkBlast.Environment
import GtkBlast.Log
import GtkBlast.Pasta
import GtkBlast.GuiCaptcha
import GtkBlast.Proxy
import GtkBlast.Conf
import GtkBlast.GtkUtils
import GtkBlast.Maintenance
import "blast-it-with-piss" BlastItWithPiss
import "blast-it-with-piss" BlastItWithPiss.Board
import Graphics.UI.Gtk hiding (get, set)
import GHC.Conc
import Control.Concurrent.STM
import Paths_blast_it_with_piss
import Data.Version (showVersion)
import qualified Data.Map as M
import Control.Monad.Fix

data MutableConfigurable = forall m. M
           {toMutable :: Env -> Conf -> IO m
           ,toConf :: m -> Conf -> IO Conf
           ,toEnv :: m -> Env -> Env
           }

interpretMuConfs :: [MutableConfigurable] -> Env -> Conf -> IO (Env -> Env, Conf -> IO Conf)
interpretMuConfs mcs env conf = foldM aux (id, return) mcs
  where aux (e, c) M{..} = do
            m <- toMutable env conf
            return (toEnv m . e, toConf m <=< c)

mutableConfigWidgets :: Builder -> [MutableConfigurable]
mutableConfigWidgets b =
    let infixr 1 ?
        (?) :: Functor f => f a -> (a -> b) -> f b
        (?) = flip fmap

        rec :: MuVar v a => (Conf -> a) -> IO v -> (Env -> Conf -> IO v)
        rec gt mv _ conf = do
            v <- mv
            setIO v $ gt conf
            return v

        build :: GObjectClass cls => (GObject -> cls) -> String -> IO cls
        build f n = builderGetObject b f n
    in
    [
     M
        (\env _ -> do
            wvboxcaptcha <- build castToVBox "vboxcaptcha"
            weventboxcaptcha <- build castToEventBox "eventboxcaptcha"
            wimagecaptcha <- build castToImage "imagecaptcha"
            wentrycaptcha <- build castToEntry "entrycaptcha"
            wbuttoncaptchaok <- build castToButton "buttoncaptchaok"
            wbuttoncaptchacancel <- build castToButton "buttoncaptchacancel"

            on weventboxcaptcha buttonPressEvent $ do
                io $ runE env $ removeCaptcha ReloadCaptcha
                return True
        
            on wbuttoncaptchaok buttonActivated $ do
                x <- entryGetText wentrycaptcha
                {-if null x
                    then captchaMessage "Пожалуйста введите капчу"
                    else removeCaptcha $ Answer x-}
                runE env $ removeCaptcha $ Answer x
        
            on wbuttoncaptchacancel buttonActivated $ do
                runE env $ removeCaptcha AbortCaptcha

            return (wvboxcaptcha, wimagecaptcha, wentrycaptcha, wbuttoncaptchaok)
        )
        (const return)
        (\(wvc, wic, wec, wbco) e -> e{wvboxcaptcha=wvc
                                      ,wimagecaptcha=wic
                                      ,wentrycaptcha=wec
                                      ,wbuttoncaptchaok=wbco})
    ,M
        (\env _ -> do
            wbuttonwipe <- build castToButton "wipebutton"

            on wbuttonwipe buttonActivated $ do
                ifM (not <$> readIORef (wipeStarted env))
                    (runE env $ do
                        E{..} <- ask
                        startWipe
                        io $ buttonSetLabel wbuttonwipe "Прекратить _Вайп"
                        io $ progressBarPulse wprogresswipe
                        updWipeMessage
                        )
                    (runE env $ do
                        E{..} <- ask
                        killWipe
                        io $ buttonSetLabel wbuttonwipe "Начать _Вайп"
                        io $ progressBarSetFraction wprogresswipe 0
                        updMessage "Вайп ещё не начат"
                        )
            return wbuttonwipe
            )
        (const return)
        (const id)
    ,M
        (\e Conf{..} -> do
            wradiomocha <- build castToRadioButton "radio-mocha"
            wradiokakashki <- build castToRadioButton "radio-kakashki"
            wradionum <- build castToRadioButton "radio-num"
            wradiochar <- build castToRadioButton "radio-char"
            wradiofromthread <- build castToRadioButton "radio-fromthread"
        
            let pastaradio =
                    [(Mocha, wradiomocha)
                    ,(Kakashki, wradiokakashki)
                    ,(Num, wradionum)
                    ,(Char, wradiochar)
                    ,(FromThread, wradiofromthread)
                    ]
        
            fromMaybe (return ()) $ (`findMap` pastaradio) $ \(p, w) ->
                if p == coPastaSet
                    then Just $ toggleButtonSetActive w True
                    else Nothing

            forM pastaradio $ \(p, w) -> do
                on w toggled $
                    whenM (toggleButtonGetActive w) $ do
                        writeIORef (pastaMod e) nullTime -- force update
                        writeIORef (pastaSet e) p

            pastaSet <- newIORef coPastaSet

            return pastaSet
            )
        (\v c -> get v ? \a -> c{coPastaSet=a})
        (\v e -> e{pastaSet=v})
    ,M
        (rec coSettingsShown $ build castToExpander "expandersettings")
        (\v c -> get v ? \a -> c{coSettingsShown=a})
        (const id)
    ,M
        (rec coAdditionalShown $ build castToExpander "expanderadditional")
        (\v c -> get v ? \a -> c{coAdditionalShown=a})
        (const id)
    ,M
        (rec coLogShown $ build castToExpander "expanderlog")
        (\v c -> get v ? \a -> c{coLogShown=a})
        (const id)
    ,M
        (\_ _ -> do
            wlabelmessage <- build castToLabel "labelmessage"
            wprogressalignment <- build castToAlignment "progressalignment"
            wprogresswipe <- build castToProgressBar "wipeprogress"

            wlog <- build castToTextView "log"
            wbuf <- textViewGetBuffer wlog
            wad <- textViewGetVadjustment wlog
            adjustmentSetValue wad =<< adjustmentGetUpper wad

            previousUpper <- newIORef =<< adjustmentGetUpper wad

            onAdjChanged wad $ do
                v <- adjustmentGetValue wad
                p <- adjustmentGetPageSize wad
                pu <- subtract p <$> readIORef previousUpper
                when (v >= pu) $ do
                    u <- adjustmentGetUpper wad
                    adjustmentSetValue wad $ subtract p u
                    writeIORef previousUpper u
            
            return (wlabelmessage, wprogressalignment, wprogresswipe, wbuf))
        (const return)
        (\(wlm, wpa, wpw, wbuf) e -> e {wlabelmessage=wlm
                                       ,wprogressalignment=wpa
                                       ,wprogresswipe=wpw
                                       ,wbuf = wbuf
                                       })
    ,M
        (\_ c -> do
            wvboxboards <- build castToVBox "vbox-boards"
        
            forM (fst $ unzip $ ssachBoardsSortedByPostRate) $ \board -> do
                wc <- checkButtonNewWithLabel $ renderBoard board
                when (board `elem` coActiveBoards c) $ toggleButtonSetActive wc True
                boxPackStart wvboxboards wc PackNatural 0
                BoardUnit board wc <$> newIORef [])
        (\v c -> do
            cab <- map buBoard <$>
                filterM (toggleButtonGetActive . buWidget) v
            return c{coActiveBoards=cab})
        (\v e -> e{boardUnits=v})
    ,M
        (\e c -> do
            wcheckthread <- (rec coCreateThreads $ build castToCheckButton "check-thread") e c
            wcheckimages <- (rec coAttachImages $ build castToCheckButton "check-images") e c
            wcheckwatermark <- (rec coWatermark $ build castToCheckButton "check-watermark") e c

            tqOut <- atomically $ newTQueue

            tpastas <- atomically $ newTVar []
            timages <- atomically $ newTVar []
            tuseimages <- atomically . newTVar =<< toggleButtonGetActive wcheckimages
            tcreatethreads <- atomically . newTVar =<< toggleButtonGetActive wcheckthread
            tmakewatermark <- atomically . newTVar =<< toggleButtonGetActive wcheckwatermark

            on wcheckimages toggled $
                atomically . writeTVar tuseimages =<< toggleButtonGetActive wcheckimages
        
            on wcheckthread toggled $
                atomically . writeTVar tcreatethreads =<< toggleButtonGetActive wcheckthread

            on wcheckwatermark toggled $
                atomically . writeTVar tmakewatermark =<< toggleButtonGetActive wcheckwatermark

            return (tqOut, ShSettings{..}, wcheckthread, wcheckimages, wcheckwatermark))
        (\(_, _, wct, wci, wcw) c -> do
            ct <- get wct
            ci <- get wci
            cw <- get wcw
            return c{coCreateThreads=ct
                    ,coAttachImages=ci
                    ,coWatermark=cw}
            )
        (\(tqOut, shS, _, wcheckimages, _) e -> e {tqOut=tqOut
                                                  ,shS=shS
                                                  ,wcheckimages=wcheckimages
                                                  })
    ,M
        (rec coAnnoy $ build castToCheckButton "check-annoy")
        (\v c -> get v ? \a -> c{coAnnoy=a})
        (\v e -> e{wcheckannoy=v})
    ,M
        (rec coHideOnSubmit $ build castToCheckButton "checkhideonsubmit")
        (\v c -> get v ? \a -> c{coHideOnSubmit=a})
        (\v e -> e{wcheckhideonsubmit=v})
    ,M
        (rec coAnnoyErrors $ build castToCheckButton "check-annoyerrors")
        (\v c -> get v ? \a -> c{coAnnoyErrors=a})
        (\v e -> e{wcheckannoyerrors=v})
    ,M
        (rec coTray $ build castToCheckButton "check-tray")
        (\v c -> get v ? \a -> c{coTray=a})
        (\v e -> e{wchecktray=v})
    ,M
        (\e c -> do
            wentryimagefolder <- (rec coImageFolder $ build castToEntry "entryimagefolder") e c
            wbuttonimagefolder <- build castToButton "buttonimagefolder"
            
            onFileChooserEntryButton True wbuttonimagefolder wentryimagefolder (runE e . writeLog) (return ())

            return wentryimagefolder)
        (\v c -> get v ? \a -> c{coImageFolder=a})
        (\v e -> e{wentryimagefolder=v})
    ,M
        (\env _ -> do
            wbuttonselectall <- build castToButton "buttonselectall"
            wbuttonselectnone <- build castToButton "buttonselectnone"

            on wbuttonselectall buttonActivated $ do
                forM_ (boardUnits env) $
                    (`toggleButtonSetActive` True) . buWidget
        
            on wbuttonselectnone buttonActivated $ do
                forM_ (boardUnits env) $
                    (`toggleButtonSetActive` False) . buWidget)
        (const return)
        (const id)
    ,M
        (\e c -> do
            wcheckhttpproxy <- (rec coUseHttpProxy $ build castToCheckButton "checkhttpproxy") e c
            wentryhttpproxyfile <- (rec coHttpProxyFile $ build castToEntry "entryhttpproxyfile") e c
            wbuttonhttpproxyfile <- build castToButton "buttonhttpproxyfile"

            on wcheckhttpproxy buttonActivated $
                runE e $ do
                    set (httpproxyMod e) nullTime -- force update
                    regenerateProxies

            onFileChooserEntryButton False wbuttonhttpproxyfile wentryhttpproxyfile (runE e . writeLog) $
                runE e $ do
                    set (httpproxyMod e) nullTime -- force update
                    regenerateProxies

            return (wcheckhttpproxy, wentryhttpproxyfile))
        (\(wchp, wehpf) c -> do
            chp <- get wchp
            ehpf <- get wehpf
            return c{coUseHttpProxy=chp
                    ,coHttpProxyFile=ehpf})
        (\(wchp, wehpf) e -> e{wcheckhttpproxy=wchp
                              ,wentryhttpproxyfile=wehpf
                              })
    ,M
        (\e c -> do
            wchecksocksproxy <- (rec coUseSocksProxy $ build castToCheckButton "checksocksproxy") e c
            wentrysocksproxyfile <- (rec coSocksProxyFile $ build castToEntry "entrysocksproxyfile") e c
            wbuttonsocksproxyfile <- build castToButton "buttonsocksproxyfile"

            on wchecksocksproxy buttonActivated $
                runE e $ do
                    set (socksproxyMod e) nullTime -- force update
                    regenerateProxies

            onFileChooserEntryButton False wbuttonsocksproxyfile wentrysocksproxyfile (runE e . writeLog) $
                runE e $ do
                    set (socksproxyMod e) nullTime -- force update
                    regenerateProxies

            return (wchecksocksproxy, wentrysocksproxyfile))
        (\(wcsp, wespf) c -> do
            csp <- get wcsp
            espf <- get wespf
            return c{coUseSocksProxy=csp
                    ,coSocksProxyFile=espf})
        (\(wcsp, wespf) e -> e{wchecksocksproxy=wcsp
                              ,wentrysocksproxyfile=wespf
                              })
    ,M
        (\ e c -> do
            wchecknoproxy <- (rec coUseNoProxy $ build castToCheckButton "checknoproxy") e c

            on wchecknoproxy buttonActivated $ do
                runE e $ regenerateProxies -- force update

            return wchecknoproxy)
        (\v c -> get v ? \a -> c{coUseNoProxy=a})
        (\v e -> e{wchecknoproxy=v})
    ,M
        (\_ _ -> do
            wlabelversion <- build castToLabel "labelversion"
            labelSetMarkup wlabelversion $
                "<small><a href=\"https://github.com/exbb2/BlastItWithPiss\">" ++
                    showVersion version ++ "</a></small>")
        (const return)
        (const id)
    ,M
        (\e _ -> do
            window <- builderGetObject b castToWindow "window1"
            windowSetTitle window "Вайпалка мочана"
        
            -- setup tray
        
            wtray <- statusIconNewFromFile =<< getResourceFile "2ch.so.png"
            statusIconSetTooltip wtray "Вайпалка мочана"
            statusIconSetName wtray "blast-it-with-piss"
        
            wmenushow <- checkMenuItemNewWithMnemonic "_Показать вайпалку"
            wmenuexit <- imageMenuItemNewFromStock stockQuit
            wmenu <- menuNew
            menuShellAppend wmenu wmenushow
            menuShellAppend wmenu wmenuexit
            widgetShowAll wmenu
        
            -- tray signals
        
            on wtray statusIconActivate $ windowToggle window
            on wtray statusIconPopupMenu $ \(Just mb) t -> menuPopup wmenu $ Just (mb, t)
            wmenushowConnId <- on wmenushow menuItemActivate $ windowToggle window
            on wmenuexit menuItemActivate $ widgetDestroy window

            onDelete window $ \_ -> do
                noTray <- not <$> statusIconIsEmbedded wtray
                closePlease <- not <$> toggleButtonGetActive (wchecktray e)
                if noTray || closePlease
                    then return False
                    else True <$ widgetHide window
    
            let setCheckActive ca = do
                    signalBlock wmenushowConnId -- prevent it from infinitely showing-unshowing window. I'm unsure if there's a better solution.
                    checkMenuItemSetActive wmenushow ca
                    signalUnblock wmenushowConnId
        
            onShow window $ setCheckActive True
            onHide window $ setCheckActive False

            widgetShowAll window
            return window
        )
        (const return)
        (\v e -> e{window=v})
    ]

mkAllWidgets :: Builder -> Conf -> IO (Env, Conf -> IO Conf)
mkAllWidgets b conf = do
    messageLocks <- newIORef 0
  
    wipeStarted <- newIORef False
  
    postCount <- newIORef 0
    activeCount <- newIORef 0
    bannedCount <- newIORef 0

    pastaMod <- newIORef nullTime

    imagesLast <- newIORef []

    proxies <- newIORef M.empty

    httpproxyMod <- newIORef nullTime
    httpproxyLast <- newIORef []

    socksproxyMod <- newIORef nullTime
    socksproxyLast <- newIORef []
  
    pendingCaptchas <- newIORef []

    (re, rs) <- mfix $ \ ~(lolhaskell, _) -> do
        (setEnv, setConf) <- interpretMuConfs (mutableConfigWidgets b) lolhaskell conf
        return (setEnv E{..}, setConf)
    return (force re, rs)