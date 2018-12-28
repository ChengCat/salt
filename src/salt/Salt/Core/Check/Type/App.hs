
module Salt.Core.Check.Type.App where
import Salt.Core.Check.Type.Base


-- | Check the application of a type to some types.
checkTypeAppTypes
        :: Annot a => a -> [Where a]
        -> Context a -> Kind a -> [Type a] -> IO ([Type a], Kind a)

checkTypeAppTypes a wh ctx kFun tsArg
 = case kFun of
        TArr ksParam kResult
          -> goCheckArgs ksParam kResult
        _ -> throw $ ErrorAppTypeTypeCannot a wh kFun
 where
        goCheckArgs ksParam kResult
         = if length ksParam /= length tsArg
             then throw $ ErrorAppTypeTypeWrongArityNum a wh ksParam (length tsArg)
             else do
                (tsArg', ksArg) <- checkTypes a wh ctx tsArg
                goCheckParams ksParam kResult tsArg' ksArg

        goCheckParams ksParam kResult tsArg' ksArg
         = checkTypeEquivs ctx a [] ksParam a [] ksArg
         >>= \case
                Nothing -> return (tsArg', kResult)
                Just ((_aErr1', kErr1), (_aErr2, kErr2))
                 -> throw $ ErrorTypeMismatch a wh kErr1 kErr2


