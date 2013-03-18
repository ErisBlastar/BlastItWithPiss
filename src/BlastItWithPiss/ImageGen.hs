module BlastItWithPiss.ImageGen
    (folderImageGen
    ,fileImageGen
    ,cloudflareRecaptchaImageGen

    ,builtinImageGen
    ,nyanImage
    ,sobakImage
    ,desuImage
    ,trollfaceImage
    ,_1pixImage

    ,getDirectoryPics
    ) where
import Import

import BlastItWithPiss.Captcha
import BlastItWithPiss.Image
import BlastItWithPiss.Blast
import BlastItWithPiss.MonadChoice

import System.FilePath
import System.Directory

getDirectoryPics :: FilePath -> IO [FilePath]
getDirectoryPics imagefolder = do
    fromIOException (return []) $ do
        contents <- getDirectoryContents imagefolder
        return $ filterImages $ map (imagefolder </>) contents

folderImageGen :: FilePath -> IO (Maybe Image)
folderImageGen imagefolder = do
    _fps <- getDirectoryPics imagefolder
    case _fps of
      [] -> return Nothing
      fps -> start fps
  where
    start fps = do
        fp <- chooseFromList fps
        go fp fps
    go fpath fs = fromIOException (start fs) $ Just <$> readImageWithoutJunk fpath

fileImageGen :: FilePath -> IO (Maybe Image)
fileImageGen fpath =
    fromIOException (return Nothing) $ Just <$> readImageWithoutJunk fpath

cloudflareRecaptchaImageGen :: Manager -> IO (Maybe Image)
cloudflareRecaptchaImageGen manager = do
    x <- try $ do
        (bytes, ct) <- runBlastNew manager $ do
            chKey <- recaptchaChallengeKey cloudflareRecaptchaKey
            getCaptchaImage $ Recaptcha chKey
        fname <- mkImageFileName ct
        return $ Image fname ct bytes
    case x of
      Left (_::HttpException) -> return Nothing
      Right i -> return $ Just i

builtinImageGen :: IO Image
builtinImageGen = chooseFromList
    [nyanImage
    ,sobakImage
    ,desuImage
    ,trollfaceImage
    ,_1pixImage]

nyanImage, sobakImage, desuImage, trollfaceImage, _1pixImage :: Image
nyanImage = Image "nyan.gif" "image/gif" "GIF89a5\NUL\NAK\NUL\243\NUL\NUL\189\255\247\255\255\NUL\255\204\153\&3\255\NUL\255\153\255\255\153\153\255\153\NUL\153\153\153\NUL\153\255\255\&3\153f3\255\255\NUL\NUL\NUL\NUL\NUL\255\255\255\NUL\NUL\NUL\NUL\NUL\NUL!\249\EOT\t\a\NUL\r\NUL!\255\vNETSCAPE2.0\ETX\SOH\NUL\NUL\NUL,\NUL\NUL\NUL\NUL4\NUL\DC4\NUL\NUL\EOT\254\176\173Ig\187\248\214\138\153\255`\232e\217f\158(#\172l\235\174\f\169\161\244\169\174D\174\239:\ESC\147\134\160\&0\136\SUB\SO\ETB7\RS!\145c\238`2\163t:U5\149X\130\224\151\161z\169\214,\193s\213\198F\151\128z\173\166\178\217\134\&0\150q80\158\158\250\239\205\239\a@jr:Ntz=\133vi~\139\DELz\f\DEL\STXb\136v\USuz\ETB\ETX\153\154\153~\154y\148rN:\147\150\165\137\r\155\169\170\169\159\RS\145J\t\164\166\165\&1\171\182\170\173\145\162\163\150\NUL\164\190\151\b\194\195\194\182\196\194 \175J\136\159v\148\193\199\209\210\199\174<\132\a\ENQ\ENQ\179\150\217\&1\211\223\211I\187c\216\218\133\231\229\&1\n\235\236\235\211\237\237\b7\202;\204\"\151\r\240\250\251\250\US/-\178ha\224G\176\159%\DC1\b\DC3\202\144\193o\225\&9\ACK\n\206\145\144(q\161\197\139\GS>\\\208(\131#\SUB\f\STX\DC1\NUL\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\DC4\NUL\NUL\EOT\254p\201)\155\189\150R\204\186\255`\135aZi\158\v#\172l\235\174\204\152\161t\169\174D\174\239:\ESC\143\134\160\&0x\SUB\SO%7\RS!\145c\238`2\163tJU5\149X\130\224\135\161z\189\214l\174\179\204m-\162F`\205^S\219\237`8\203\&8\FS\CAN\189X\253\174\134\251\255\DELs:N\EOT{wf\GSv|\128\140m\GSl\130J\134w\RS\138|\ETX\152\153\152\128\154{\fks\132:\147\150\150\&1\154\168\169\168\158\RS\STXXL\164\165\166\170\180\169\147V\162\163\138\NUL\164\188v\f\b\193\194\193\180\195\193\137w\174t\138\200w\148\191\198\209\210\209\173<\132u\ENQ\ENQ\178\138\217\192\211\223\211I\185\133\a\217\206\231\216\ENQ\f\n\236\237\236\211\238\238\199,\203\191!\191\r\241\250\251\252\GS/.\177LY\224G\176\159\189\DLE\b\DC1\202\CAN\193oa>O\n<\201\144(\209\161\197\139\r<\\\208\&81\rG\v\STX\DC1\NUL\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\NAK\NUL\NUL\EOT\254\176\201\&9\151\189\150R\140\181\255\NAK'\142$c\158hj\130\r\233\186\140 \207t-3 i\236\252\174\199\&2\130pH\FS\206p\158\158r\201\228\SOH\139\132\132PJ\188}\154\216fl\n\237\DC2\EOTHM3@.\147\199[\175\208\DC4\NAK\130%+\137yN\175\151\211^\198\225\192\&0\226\244|rv\131uxCT\EOT\128|n&{\129\rv\ETX\146\147\146\145\134P\138|'\142\143\148\158\159\160\147x\136C\153\156\156H\161\170\160&\STX]R\166\167\168\r\161\b\182\183\182\158)\174\164\165\142\NUL\166\192{8\184\197\198\184\141\142\151D\138\201|\154\195\r\199\211\200\202\173E\136z\ENQ\ENQ\178\142\219\196\199\n\226\227\226\200'\nO\189\137\a\219\207\238\218\ENQ8\228\243\244\245\227@\174]\205*\209\r\246\255\246Z\217\160\DC1k\150\EOT{ \DLE\234Q\193\176a\CAN\SYN\DLE?\NUL\250\211\143\194\196\ACK\ETB#j\212pbBG\SI\ENQ\US?6\136\NUL\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\NAK\NUL\NUL\EOT\254\176\201)\151\189\150R\140\181\255\DC3'\142\164\197\156h\170\158`\233\146\140 \207t-3\USi\236\252\174\ESC1\EMaH,\DC2g8Mo\201l\246\130FBb8-\222<\206l6F\141z\t\130$\197\EM(\155\203\228\NUL\247;<I\135a\t\171q\174\219\239\231\245\151q80\142\&8|~tx\133xzDU\EOT\130~p'}\131x\ETX\147\148\147\146\ETX\136Q\140~(\144\131\149\160\161\162\149z\138D\155\158\158\&8\163\172\162(\STX^S\168\169\170\163\b\183\184\183\161\143~\176\166\167\144\NUL\168\194}\f\185\199\200\200\155\153E\140\188~\156\197\201\211\199\130)\176E\138|\ENQ\ENQ\180\144\220\198\201\n\227\228\227\185\214\227P\191\139\a\220\208\239\219\ENQ\f\229\244\245\245'\228A\216\154\144+\214\r\246\STX\nL\167\207\198\ro\253$\EOT\EOT\177\208\154\191\135+@H\156\216\224\223?\r\SYN\139Q\220\232\SOH\197\EOT\143\ACK\GS\231\128\148\DLE\SOH\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL4\NUL\NAK\NUL\NUL\EOT\254\176\173Ig\187\248\214\154\187\255\222&\142\228\194\156h\170\158`\233\142\140 \207t-3\159\161\239:\201\243\166\EMaH,\DC2g\184\206o\201d\198\EOTFBb8-\222<\205l3F\141z\t\130d&@.\147\155f\179\129\251%\156\186`\FS\235\146\174\219\237l/\227p`XO|Iw\131wyDU{\129G\137}\ETB\ETX\143\144\143w\144)\ETX\SOH\134F\140}(|\129\142\145\160\161\143\140)PpD\154\157\170\141\r\162\174\148\154'\166F\t\169\171\170\&8\b\186\187\186\174\188)}PUE\140\NUL\169\198\158\188\202\203\204\b(\179\153\157\128\129\155\201\205\215\204\152\136\a\ENQ\ENQ\183\157\221\&8\n\227\228\227\205\229\229\206\&2R\209\221}\212\239\225\r\232\244\245\244\178\235Q\164+\158\243\246\255\232J\217@\242M\SUB\b\f\246<\236[\193\144\225\193\135\US\DC2\201\233\151Ab\ETX\139\DLE3V\156s\145\227\198$\EOT(:D\NUL\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL4\NUL\NAK\NUL\NUL\EOT\254p\201)\155\189\150R\204\187\239Z(\142\DC2c\158hjzd;2B,\207t\204tF\174\231\227\190\151\&2\130pH\FS\202n\CAN\159r\201\132\t\138\132\132PJ\180q\152X,l\n%\152\138\130\219\170\DC1(\155\203\204\243\&9\183\237z\SI\aFT\CANf\192o\234\188~\223\238\218\239F\DELqd{\133f&\135OET\130q'pw\r\ETX\147\148\147{\149\DEL\fe}P\141\144\159\131\149\162\163\162\153'\138sC\158\160\159\f\164\175\163\141\156C\t\130\NUL\158\183w\b\187\188\187\175\189\187&wOTD\130\194w\142\186\192\204\205\192\167nv\ENQ\ENQ\172\144\211\f\206\217\217\179\140\a\211q\201\224\215\n\228\229\228\206\230\230\193\&1\169\198\144*\153\r\233\243\244\244&A~\213\239\SYN\245\253\246\142\&5h\192;\241\225B=\SI\199\ACK*\FST\176\225\135x\241\&8@\140\228\176\"\ACK\130\r0J\FS\147\145\163\133\b\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL4\NUL\DC4\NUL\NUL\EOT\252\176\201\&9\151\189\150\210\203\186\255`\167UXi\158\156\160\174l\171\&2c\131\206(\179\DC2x\174\231+\172\161\134\160\&0\b\180\tv\132\EOTN\169{\141\134\208\168Th[\"\175\EOT\129\143\&2\237N\171XB\199\154\133\137$\211\128z\173N\131\175\140\195\129\209\236\200}\236\188\158\253Q\191sLqw<\130s\DC2{\136|w\f\SOH\DEL;\133s\RSrw\135{\ETX\151\152\151kv\145oL9\144\147\162\134\r\153\166\167\166\156\GSGH\t\161\163\162\&0\168\179\167\170G\159\160\147\NUL\161\187\148\179\b\192\193\192\181\RS\172H\133\156s\145\148\194\205\206\207\192\171;\129\a\ENQ\ENQ\176\147\214\&0\208\220\208FI\143\213\215\130\228\226\219\207\n\233\234\233\208\nF\198:\200!\148\r\235\246\247\248\233\197.=\216\147[\249\STX\222\147\ETB\162`\b\n\249b\212\ESC\184\168\SOH9\r\SI\US*\156H\241\131\EOT\SI10:\220\"!\STX\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\DC4\NUL\NUL\EOT\254\176\201)\151\189\150R\204\186\255`\167MXi\158%#\172l\235\174\204\216\160\&4\173\174D\174\239:\ESCk(\131p(\f\SUBn<B\"\183\220\193F\196\168tJT1\147X\130\224G\161z\189\214l\174\163\204m%\162\ACK5\192n\179\215\129p\150q80z1\186\189\225\238\251\255nr:M\EOTzvf\GSu{\128\140\129\fm\130I\134v\RS\138\139\DEL\ETX\153\154\153\129u\f\153r\132:\147\150\150\&1\155\168\169\168z\US\STXXK\164\165\166\170\180\169\147V\162\163\138\NUL\164\188\158\180\b\193\194\193\182\172\174s\138\137\158\148\158\195\206\207\208\193\RS\199\131\186\ENQ\ENQ\178\138\215\f\209\221\221H\185\133\a\215v\203\229\219\209\n\234\235\234\233\n7\212<\134!\172\r\236\247\248\249\236\GS/.\177\166\DC2\244\t\212\199\138\158\193\DLE\DC3\244\201\176\151\175A\189z\SUB\RSzZH\177\"\154\&4\SO1R\240p\145K\131\b\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\NAK\NUL\NUL\EOT\254\176\173Ig\187\248\214\154\187\255\223&\142\228\194\156h\170\158\160T\190\"#\204tm\207\fh\236\252N\246=\DC3\141@,\SUB\139\180\156\a\200l6e\130#!A\164\SUBq\US\167\214)\171J\191\EOT\129\178\DC3(\155\203\206\243\217\208\ENQ\DC3OS\162\248\194\186\168\239x|\ESC\204\&8\FS\CANH9}\DELvy\134zQGV\EOT\131\DELr'~\132\r\ETX\148\149\148y\150\150\SOH{_\141\DEL(\145\146\153\163\164\164{\139E\158\161\161J\165\174\166\156ET\170\171\172\r\b\184\185\184\165\186\b*Q\168\169\145\NUL\170\196~9\189\201\202\190\158\177F\141\144\199\159\199\183\203\214\190\145(\137\178\194\ENQ\ENQ\181\145\222\&9\n\228\229\228\203\230)\190\&3qG}\222\DEL\210\241\226\r\230\246\247\248\229P\219\238\217+\212\245\242\t\196w\226\134\rZ\182Z\EOT\188\aBA\159\NAK\DLE#\142QH\177\195 A\NUL3\\l\176\177\162G\f\t(@\214\177X'\228\133\b\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL5\NUL\NAK\NUL\NUL\EOT\254p\201)\155\189\150R\204\187\247Z(\142\DC2c\158hj~d;2B,\207t\204xF\174\231\227\190\151\&2\130pH\FS\202n\FS\159r\201\132\t\138\132\132PJ\180u\152X,l\n\237\DC2\EOTHL`L\RS3\203\229\220\214+4E\133`\203\170\129\174\219\239k/\227p`\CANo{}tw\132xOET\EOT\129}p&|\130\ETX\145\146\145w\147\147cy]\139}'\143\144\150\160\161\161y\137C\155\158\158\&7\162\171\163&\135\136\138\168\178\143\f\b\182\183\182\162\184\182\142}O\165\166\143\NUL\167\195|\181\187\200\201\188\169\175P\139\189}\156\198\202\212\183\129(\205om\a\ENQ\ENQ\179|\221\f\n\227\228\227\202\229\215\188\&1\218D{\221\209\240\238\ENQ\226\229\245\246\245&\228N\217\193\198*\198\r\238\t\FS8\206U\141\EM\167P\133\241 \240\131\130k*\"J\252@\177b\131k\ETB\SOHr\192\136\209\162\199\141\ts.\134\196pB\206\200\b\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL4\NUL\NAK\NUL\NUL\EOT\253\176\201\&9\151\189\150R\140\181\255\DC2'\142\228\194\156h\170\158`\233\142\140 \207t-3\USi\236\252\174\199\&2\130pH\FS\206p\154\158r\201\228\SOH\139\132\132PJ\188y\154\216fl\n\237\DC2\EOTHJ3@.\147\199[/\225\196\253\226X\DC2\179|N/\167\187\140\195\129Q=\233\145u\129uwCTy\DELF\135{qt\ETX\142\143\142v(\SOH\ETX\132E\138{(z\DEL\DC2\144\158\159\143\138)\STX\133\151\155\167\168H\160\171\161\152'\164P\t\152\168\169\r\171\b\184\185\184\144){\164TD\138\NUL\179\195\156\186\199\200\201\b(\176P\162\162\153\198\202\211\201\150\134\a\ENQ\ENQ\180\155\217\&8\202\n\224\225\224\223O\192By\217{\DEL\235\221\r\226\239\240\241\224\175A\206\155+\135H\242\251\240\163\&6G\219\238M\144\a\162\223=|\bW\128X\184\&0_\ETX\135\SUB\FSBdH1\"\156\135\ETB)\160\144\176\145B\EOT\NUL!\249\EOT\t\a\NUL\r\NUL,\NUL\NUL\NUL\NUL4\NUL\NAK\NUL\NUL\EOT\254\176\201)\151\189\150R\140\181\255\NAK'\142\228\194\156h\170\158_\233\146\140 \207t-3\RSi\236\252\174\ESC1\EMaH,\DC2g8Jo\201l\246\130FBb8-\222\&4\206l6F\141\DC2NF\SOH\142\213p\ACK\206\232\179\&9\192\245~\SI\a\134t(f\192q\233\188~\159n{\237wG\128q\r|\134}\fh~DU\131q(pw\133{\ETX\149\150\149}w\149\139F\142\145\159\132\151\162\163\162\128)\STX\140E\158\160\159\f\164\175\163\142\156T\131\NUL\158\182\154\164\b\187\188\187\177\166\168U\170\145'\196\143w\189\201\202\203\187(\168\DEL\a\ENQ\ENQ\172\145\210\f\204\216\216\156\141\209\211\166w\221\215\203\n\228\229\228\204\228P\194D\131+\166\r\230\241\242\243\229'3n\171\173\DC2\244\252\243v\246\&6h\184C1\129\RS\b\DEL\196\ACK*$\EOT\162\161\195w\239\&4@\148\228\176\162\a\130\r0J$\147\145\163\132\b\NUL;"
sobakImage = Image "sobak.gif" "image/gif" "GIF89a\RS\NUL\CAN\NUL\247\255\NUL\133w\152pJ\ESC{T*\210\172\139\152c;\234\236\253a4\EM\186\157\129\186\234\200tPSXD4\133iY\165\138|\179\130Y\149\210\149xC5\202\183\154\174\137i\195\162\131\228\199\183\186\154{U3\SUB\205\152\154\212\178\147\226\228\167\132\174z}N-\200\159\137\152fX`J\CANhA9vXiqPI\136V[\209\139\146\214\222\252\130Q-\140]9\213\189\165\219\218\155W=4sE%\176\141l\178v\164\187\147l\164vS\150xb\150\144\207rSD\207\168\129\231\220\213\204\132\140\140pY\204\163{\148eD\217\178\140sL.aBB\133jg\178\136`g@0\172\DELZmA#\179\181\234\159|\\\171{X\158\131h\193\157y\156oL\152tP\189\160\133\152jD\189\153u];\"\189\141c\205\166\134$\GS\EM\195\166\137\147u\\\171\129g*%&\139Y5uL\"\233\244\251\184\141j\234\236\244\211\173\135\163mF\185\151td< \235\218\228j=!\180\148s9*\"\190\149rzY<\200\173\148\&2!\ESC}]I\131U4\SUB\SYN\SYN\147hE\163\132fsHI\128M&\189\150u\147pS\131aFR>/\149jJ\145[F\208\174\141\139cE\182\149v\149^6\141bKjU\"nI'\193\153xyI'\201\169\137\199\169\140\167yR\177\131`B2+{\165p\137U/\181\147u\199\158zU,\DC4e7!\200\167\135jE*\157wV\159\133p\204~\190e;@\200\128\130\178w|\229\238\255\171{U\234\224\253\204\170\142\222\185\150uZL}\\B\208\170\137\218\244\239\144`>\221\200\180\194\160{\151y_\189\132\179\152rX\159\139\130\206\189\164\218\165\168\222\171\176ml;^K@\226\189\156\191\170\146\191\182\149N;8Q.*\224\182\188\233\203\236\155\223\165\235\222\253\162\134j\167\136nfP3\170\136g\128OT\193\148q\212\145\141\205\200\148\211\202\135\136X.\168\144\139\192\158\DEL\152gB\132\153u\128V8\129ZA\136W0\136X;\132H6\141tg\153cj\161gm\170qf\181\DEL\128\231\240\223\223\244\243\231\179\240\166~\\\233\239\198\231\238\211\227\208\192j}My^R\DELfUzvPeB(\178\233\189mI/\132P\"a=;\193\155}\205\163\140mYCa1)j5+i8*]79\166\162\220qTU\234\235\237}TG\198\132\135\197\130\137\157\157e\204\160\210^B\ETB\222\145\226\208\243\227\131\144m\214\241\233\220\204\184\178\145o\187\144f\143\199\144U0'\177\162\136:2*410\187\150s\207\140\200\216\207\176\197\151k\222\200\178\218\150\215\223\204\181Q/\SOX@0\177\147t\180\144r\CAN\FS\"\202\166\128\217\219\170\176pq\175\148{\186|xsP9\234\244\255!\249\EOT\SOH\NUL\NUL\255\NUL,\NUL\NUL\NUL\NUL\RS\NUL\CAN\NUL\NUL\b\255\NUL\255\t\FSH\240_\129o+\NUL(|\129\237\199\136\DC1\139\nJ,\216\bS\bp\SOH\EOT\b@#%\NUL\137\SI\184>\188\CAN1Qb\184\DLE\GS\164\144\160\EOT\164\SYN\165\DC2Q\252<\171SGJ6\NUL?J\254C%\239\150\148;Qj\GS!B\164E\EOTbGr\165\240\145$\139\SOHA\232$\SYN8\196A\128,\DC2%\130\236iq%\136\157A^v\FS\185\147\"\133\160\n\NAK\EOT9 X`\ENQ\GS\SOHR\208\248\233a\199\142\ETB*T$YQ\178\167P\153;$Rd\201\146\132\a\130\129\238\232\224\216\226\ETX\r\SOH*J\148\196\144\180\228\205\163\&4l\152\248+qG\206\GSB\204\170\245\DC18\236\129\SI\USY\NUL\235a\209\162\193\141\ESC\ETB\ACKX\137\&0\138L\151\DC2\SUBr\213\194A\200\218hSg\232\EM0\144\197\SI\129\GSl\160\136\129Wc\t @,p\213\251r\164\r\t]\186\156Q\203P\197M\133@\129\f\248\255\144\195H\SI\DC3|\159\SUB\NUL\SUB\146\166\157\132{^\236\DLE\SOH\STX\199\211\SUB\FS\233NqJ2|\184\ACK\STX=4\DLEI2O\184\&2\132\EOTy\f\242F\DC3\a`QH\DC1\FS8\144\193\ETX\164 \208O\DC2\130l\161a\DC4W\156\195B\r\160,\DC1\141#\ETB\180\ETB\129\EOTF\152\SOH\132\SUBs4C\206\&8\182\b\211I\GS\167\249p\a\SOH{\f\129\132%\ETB\208b\196\ESCq\212\211E\CAN\159\224\161\138\SUB,\RS6P\SOH\191\224\160\129\ACK$\212\178\ETX\SYN\DELP\128\a\ETB\DC2\\0\r\EM\236@A\134\v\DEL\172\161\198\&2\226\DC4\164\133\ESC\254\140\DC1\133\r=\176\160B\FSC\176B\203\ESC\n\144\193\EOT\DC3P,\128\ENQ\r\v 3\137D\165\248sK\t6\DLEA\ENQ\DC2*\168p\162$NtA\134m\134\152#\196\STX\222L1Q\"\171P\210\ACK+r\210b\134\DLE\DC2\224q\NUL$|\240\145\f?\169\208\160C,%i\177\203\ETBp\FS\147`\196\USM\128A\131\DLE`\CANA\195'\235\160\192\ACK\ESC\151\&0p\130N\SYN\240\242\n?&\128q@\RS\DC1\176\241\201\&6g$\160C/\136(`\207,\250\232\&4\208\ACK\DLE\196c\130\DC1\249d\DC2F+3\136`\193\f\138\136\193\128&\193h;\144\f\155\204SI\DC3\249\&8\225\SOH7\"\136\&0\ETX000\128\129\187\EOT\GS\ETX\193;\229\132\130\132?!\236\211\141/\208$\243/\192\EOTU!\195\&1\DC3H\227\STX\b\215\156\145\131\&2\195B\172\147\&6\197\192\162\142(\198\232\DC4\DLE\NUL;"
desuImage = Image "desu.gif" "image/gif" "GIF89a\RS\NUL*\NUL\198y\NUL\NUL\ACK\NUL\DC3\SO\v\ETB\DLE\v\a\ETB\SI\DC3\SYN\SYN\RS\NAK\DLE\v\"\SYN#\GS\SUB'\GS\ETBI\NAK\ACK+\RS\ETB.\US\ESC #(\SI.\RS\ESC-%\RS1\EOT;* \ESC7&,11\SYN:'\GS8+\USB-/>>\GSF1$E5-C:\146*\f0D0S:,9AA>@?CA/[>5&N7@DPZ@/9L6$R:/W=;SEJNNjJ8+^C<b\trMBqO<H[SWXL6cF4gJxTA\198@*vXF?kL\129YG=oP|]K`dx\136^K\138]Q|dWFwV\133eT\145cRymbJ\131\DC3jrq\152hVrqnO\128\\lyk\146o_\138tgR\142\SYN\168ra~|{\162yjx\132}\149~s\156}mz\133\130\173zk\151\131u\128\134\160\184|l\132\139\136\167\138y\161\141\130\139\151\147\175\144\128\166\149\138\171\152\140\177\154\136\170\157\148\155\161\161\179\162\148\185\165\152\189\168\150\212\166\146\171\177\177\185\177\170\193\176\165\201\178\158\186\187\185\197\187\180\213\186\171\189\192\191\198\192\186\213\192\173\200\197\192\213\206\201\210\210\209\253\201\179\215\211\207\253\211\191\238\217\196\226\221\217\228\226\223\254\221\204\242\238\232\252\240\230\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255!\249\EOT\SOHd\NUL\DEL\NUL,\NUL\NUL\NUL\NUL\RS\NUL*\NUL\NUL\a\254\128\DEL\130\131\132\NUL\NULKjyyjK\134\132\143\144\133yn_a\150a_ny\NUL\145\157\DEL\NUL\RSyalss\163\164lay\RS\156\158\131\NULjta\165\165l\164\180atj\173\158\176\178W\166aV\195V\150sW\185\187\189juaWV)JT\211\211:J)V\200u\202\145K\162sf\210\212\212\&2\211Jf\166yK\145\NULyulf\227\226C:>\227flu\155\143\237y]R\242\134H\ESC\161\195\138\141qO\186(\226\245I\US\146\DC4\213\168\248\CAN\"CG\n\USp\162P\209\&1-\ENQ\DC2w\f\255Hh\227d\b\149!?d\136\249\145BL\n\SOi\228\200\248\&1m\136\148\&6\DC2\"IpBE\154\SO1GT\226q\137gh9iNrv:@E\134\146\SYNK 0\193\147\ACK\SI\FS-K\150\180\160H\ENQ\129+\NUL:d\f\145\160A\ETX\128\162U\SOH\172X!\129\162\142\144\254\252\144\136\NAK\146G\ETX\DC12E\203\208]!$,\DC2\184\132\EOT\\\DC1\139f\198\140%E\139B\t\146\228\140\f\EMW\STX\184\STX\177\197I\138,\t\DC2$N\252\224A\150\DC4N\184\128p\181c\148\SI\EMp6o\134#\195G*\SYN\174\168\140\186\&2\164%\156\219\184]BNE\165\151l$ad\DC4\169\STX$\202m+H\170\DC4\209\DC1\ACK8\NAK\192\159d\155\SUBR\164\205\152%\DC2$,\EM\211\166\200\144Ya\158wZ =L\145\"k\222\160\192\226\ENQ\197\155\&5\231\193SQ\208i\SUB\CAN\224\231\219\228\EM\243\198\250\162\248\206\245\ACK\t\NUL'!\145\202\ACK*`\145\135\ENQ\219X\144\a\SYN*l0\n\DC2\FS\133\EOT\192\SOT\224p\137\f\DC3T\161H\NAKU\220\145G\NAK\DC3|g\137F;\240B`S\179\152bB\FS\DC3\184\208\196\t'4\225B\EOTq\152\208bx\211p\178\162\&5-\250\208@\RS\DC4d@A\ESCm4\254\160d\RS\r\240PJ\CAN\226<\a\194F=]\SOH\156\f\US\CAN\SOH\197\ENQJ*yA\DC3F| CsWl$\r\b?\RS1[\v4\188`G\DC15(YC\DC1v\188@C\vW\164rDOo\DC1\CAN\214\142\194\193`B\DC1=\DC4z\158\t0,\ahS>Rq\EOT*?\144P\EOT\ACK\r\156gi\f\rLP\EOT\tQ\160\194\131x\130\144\ETB\133%\194\NAK\161B\SI\148\158\151i\SI\231\245`\162F\v\188\&2ME2Pp\158\n\132\246\&0\193\EOT\172\222p^\f\EM8e\DC2\168\DEL\128\240\CAND\DC4TP\196\r\190\178j\169\165\NAK\\@E\n\NAK\141&\200\DC4S,\160\132\f\NUL\220\218@\b\207\158\199\229\EOT*\220\NUL@9\v`\251\a\ETX\216RQ\NUL\NUL\149\198\128\235\EOT\DC4\f\n\131\146*\228{C\f\SO\NULP\NUL\NAK\216\&2 B\192\239f`*\174E\196p\SOH\ENQ\ETB\248z\176\188\r\248\203\238\DC4\"V\252\129\237\DC49\136\NULo\ETX\b\199\224\241\179\249\150@A\196\&9\\,\200\196\SOH\SI\208A\ETX\172\170PB\184\r\CAN\208@\a\ETB\aLH\205S0\176q\151!\132\144\129\204\"\f\\s'Bc\v@\208\&9d\208\NUL\SOH\GS\160\140m\197\174\fR4\197%_\fu$\129\NUL\NUL;"
trollfaceImage = Image "trollface.gif" "image/gif" "GIF89a\RS\NUL\EM\NUL\227\SO\NULXXX\221\221\221\184\184\184\236\236\236\167\167\167\139\139\139vvv\198\198\198\243\243\243***\211\211\211\US\US\US888\204\204\204\255\255\255\255\255\255!\249\EOT\SOH\NUL\NUL\SI\NUL,\NUL\NUL\NUL\NUL\RS\NUL\EM\NUL\NUL\EOT\254\240\201)\217\186\CAN3\ACK\168\247\ESCg\CANEI\DLE\194q\f\200\214}\DC2\192\b\132r\160B\211(\n1\SYN\141\129\195a\128\SOH\n\195S\129\DLE@\f\a\EOT\abp0\172\132\140\SIc\184\SUB\"\162\195\134\&4 T\CAN\130\SOB\150\178u\144U\212\161c`\NUL\\\CANL\231p]!\168\b\v\t\ETB\STX\SOHs\f\ENQ\ETX\EMg\b\SOH\ENQ2\DC2\t\EOT;d4\ACK\SYNHt\NUL\ACK\STX\155~U\ESC\STX\STXY\t\ru$\SOH\133\SO\NULz\b\nIGu%\a\f\n\ENQ\f\t\n\168\EOT\NUL\NULb\155r<Bn\a\185\ACK\t\b\r\NUL\SOH\183A\201r$^\nG'\a\140\142\187\f\b\ACK\ETX\FS\136v\185\SO\n\fA\141\ETX\230\a\ENQ\198\NUL~\f+\ENQ\203\SI\NUL\137\ETB\219\SO\aG\b_\ACK\vG\181\f\150\152\224=`\DLE\128\US\t^#\234h\226\196c\159\166l\134&l\185S\"\128\166R\EOT\DLE\b\176c\208\150\FS\129n\ETX\GSd\CAN9r\156\131\ACKm\246\176q`\129$\134\&3\247\FS\136\146\227\134OH\150\"\172(S%g\131\SOH\154 +<\243)\128\212,[\255h\214\252\176@\202\208\DLE>\135\228\CANR\208\230\132\166\STX\148j\rE\245\STX\f\t\v\n\253T\170\131k8\175_\193\166\SUB!@A\131|p\v.H\235!\172\214\154\CAN\232\194\200\NUL\213\170^\t\DC1\NUL\NUL;"
_1pixImage = Image "ps.gif" "image/gif" "GIF87a\SOH\NUL\SOH\NUL\128\NUL\NUL\NUL\NUL\NUL\NUL\NUL\NUL,\NUL\NUL\NUL\NUL\SOH\NUL\SOH\NUL\STX\STX"