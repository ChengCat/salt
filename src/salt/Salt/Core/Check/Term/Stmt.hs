
module Salt.Core.Check.Term.Stmt where
import Salt.Core.Check.Term.Base
import Salt.Core.Codec.Text             ()
import Text.Show.Pretty


checkTermStmt :: CheckTermStmt a

-- (t-stmt-proc) ------------------------------------------
checkTermStmt a wh ctx _tsReturn (MStmtProc mProc)
 = do   (mProc', esProc)
         <- contextCheckProc ctx a wh ctx [] mProc

        return  ( MStmtProc mProc'
                , esProc)

-- (t-stmt-if) --------------------------------------------
checkTermStmt a wh ctx tsReturn (MStmtIf msCond msThen)
 | length msCond == length msThen
 = do   (msCond', esCond)
         <- checkTermsAreAll a wh (asExp ctx) TBool msCond

        (msThen', essThen)
         <- fmap unzip
         $  mapM (checkTermStmt a wh ctx tsReturn)  msThen

        return  ( MStmtIf msCond' msThen'
                , esCond ++ concat essThen)


-- (t-stmt-loop) ------------------------------------------
checkTermStmt a wh ctx tsReturn (MStmtLoop mBody)
 = do   (mBody', esBody)
         <- checkTermStmt a wh ctx tsReturn mBody

        return  ( MStmtLoop mBody'
                , esBody)


-- (t-stmt-update) ----------------------------------------
checkTermStmt a wh ctx _tsReturn (MStmtUpdate nCel mNew)
 = do   let uCel = BoundWith nCel 0
        tCel    <- contextResolveTermBound ctx uCel
                >>= \case
                        Nothing -> throw $ ErrorUnknownBound UTerm a wh uCel
                        Just t  -> return t

        tCel'   <- simplType a ctx tCel
        tVal    <- case tCel' of
                        TCel t  -> return t
                        _       -> throw $ ErrorProcUpdateNotCel a wh tCel'

        (mNew', _tsNew, esNew)
         <- checkTerm a wh (asExp ctx) (Check [tVal]) mNew

        return  ( MStmtUpdate nCel mNew'
                , esNew)


-- (t-stmt-call) ------------------------------------------
checkTermStmt a wh ctx _tsReturn (MStmtCall mBody)
 = do   (mBody', _, esBody)
         <- checkTerm a wh (asExp ctx) (Check []) mBody

        return  ( MStmtReturn mBody'
                , esBody)


-- (t-stmt-return) ----------------------------------------
checkTermStmt a wh ctx tsReturn (MStmtReturn mBody)
 = do   (mBody', _, esReturn)
         <- checkTerm a wh (asExp ctx) (Check tsReturn) mBody

        return  ( MStmtReturn mBody'
                , esReturn)


-----------------------------------------------------------
checkTermStmt _ _ _ _ mm
 = error $ "checkTermStmt: "  ++ ppShow mm