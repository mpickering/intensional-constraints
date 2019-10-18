module InferCoreExpr
    (
    ) where

import InferM
import qualified Data.Map as M
import Control.Monad.RWS
import Control.Monad.Except
import qualified GhcPlugins as Core

isConstructor :: Core.Id -> Bool
isConstructor = undefined

infer :: Core.Expr Core.Var -> InferM (Type, ConGraph)

infer (Core.Var x) =
  if isConstructor x
    then do
      -- Infer Constructor
      (d, args) <- safeCon x
      ts <- mapM fresh args
      t  <- fresh $ SData d
      case insert (mkCon x ts) t empty of
        Just cg -> return (mkConType ts t, cg)
        otherwise -> error "Cannot resolve constriants."

    else do
      -- Infer Monomorphic Variable
      (Forall ts xs cg u) <- safeVar x
      if length ts == 0
        then do
          ys <- mapM fresh $ map (\(RVar x p d) -> SData d) xs
          let m = M.fromList (zip xs ys)
          v  <- fresh $ sortFromCoreType $ Core.varType x
          case do
              cg' <- insert (sub m u) v cg;
              foldM (\cg (x, se) -> substitute se cg x) cg' (M.toList m);
            of
            Just cg'' -> return (v, cg'')
            otherwise -> error "Cannot resolve constriants."
        else
          error "Polymorphic variables must be fully instantiated."