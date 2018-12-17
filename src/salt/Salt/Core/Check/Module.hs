
module Salt.Core.Check.Module where
import Salt.Core.Check.Error
import Salt.Core.Check.Where
import Salt.Core.Check.Type
import Salt.Core.Check.Term
import Salt.Core.Check.Context
import Salt.Core.Exp
import qualified Control.Exception      as Control
import qualified Data.Map               as Map


---------------------------------------------------------------------------------------------------
-- | Check a whole module.
checkModule
        :: Annot a
        => a -> Module a
        -> IO (Context a, Module a, [Error a])

checkModule a mm
 = do
        -- Extract a list of signatures for top-level declarations.
        -- TODO: kind-check these before adding them to the context.
        let ntsDeclTerm
                = [ (n, makeDeclTypeOfParamsResult pss tsResult)
                  | DTerm (DeclTerm _a n pss tsResult _mBody) <- moduleDecls mm ]

        -- Build the top level context.
        let ctx = Context
                { contextModuleTerm     = Map.fromList ntsDeclTerm
                , contextLocal          = [] }

        (ds', errss)
         <- fmap unzip
                $ mapM (checkHandleDecl a ctx)
                $ moduleDecls mm

        return  ( ctx
                , mm { moduleDecls = ds' }
                , concat errss)


-- TODO: throw proper arity errors.
makeDeclTypeOfParamsResult :: [TermParams a] -> [Type a] -> Type a
makeDeclTypeOfParamsResult pss0 tsResult
 = case loop pss0 of
        [t]     -> t
        _       -> error "arity error when making decl type"
 where
        loop []                   = tsResult
        loop (MPTerms bts : pss') = [TFun (map snd bts) (loop pss')]

        loop (MPTypes bts : pss')
         = case loop pss' of
                [t] -> [TForall bts t]
                _   -> error "arity error when making decl type"


---------------------------------------------------------------------------------------------------
-- | Check a declaration and handle any errors that we find.
--   TODO: track a map of top level decls with type errors.
checkHandleDecl
        :: forall a. Annot a
        => a -> Context a -> Decl a -> IO (Decl a, [Error a])
checkHandleDecl a ctx decl
 = Control.try (checkDecl a ctx decl)
 >>= \case
        Right decl'             -> return (decl', [])
        Left (err :: Error a)   -> return (decl,  [err])


-- | Check the given declaration.
checkDecl :: Annot a => a -> Context a -> Decl a -> IO (Decl a)

-- (t-decl-kind) ------------------------------------------
checkDecl _a ctx (DTest (DeclTestKind a' n t))
 = do   let wh = [WhereTestKind a' n]
        (t', _k) <- checkType a' wh ctx t
        return  $ DTest $ DeclTestKind a' n t'


-- (t-decl-type) ------------------------------------------
checkDecl _a ctx (DTest (DeclTestType a' n m))
 = do   let wh  = [WhereTestType a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m
        return  $ DTest $ DeclTestType a' n m'


-- (t-decl-eval) ------------------------------------------
checkDecl _a ctx (DTest (DeclTestEval a' n m))
 = do   let wh  = [WhereTestEval a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m

        -- TODO: check effects are empty.
        return  $ DTest $ DeclTestEval a' n m'


-- (t-decl-exec) ------------------------------------------
checkDecl _a ctx (DTest (DeclTestExec a' n m))
 = do   let wh  = [WhereTestExec a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m

        -- TODO: check effects are empty.
        -- TODO: check expr returns a suspension
        return  $ DTest $ DeclTestExec a' n m'


-- (t-decl-assert) ----------------------------------------
checkDecl _a ctx (DTest (DeclTestAssert a' n m))
 = do   let wh  = [WhereTestAssert a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx (Check [TBool]) m

        -- TODO: check effects are empty.
        return  $ DTest $ DeclTestAssert a' n m'


-- (t-decl-term) ------------------------------------------
checkDecl _a ctx (DTerm (DeclTerm a n tpss mtResult mBody))
 = do   let wh   = [WhereTermDecl a n]
        tpss'    <- checkTermParamss a wh ctx tpss
        let ctx' =  foldl (flip contextBindTermParams) ctx tpss'

        (mBody', _tsResult, _esResult)
         <- checkTerm a wh ctx' Synth mBody

        -- TODO: result type needs to be a vector.
        -- TODO: check against result type.
        -- TODO: check result type.
        -- TODO: check effects are empty.
        return  $ DTerm $ DeclTerm a n tpss' mtResult mBody'

