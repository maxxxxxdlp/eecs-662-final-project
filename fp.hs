{-# LANGUAGE GADTs #-}
{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

-- Imports for Monads

import Control.Monad

-- TY ::= Num | Boolean | TY -> TY

data TYPELANG = TNum
              | TBool
              | TArray TYPELANG
              | TYPELANG :->: TYPELANG
              deriving (Show,Eq)

data VALUELANG where
  NumV :: Int -> VALUELANG
  BooleanV :: Bool -> VALUELANG
  ClosureV :: String -> TERMLANG -> ValueEnv -> VALUELANG
  ArrayV :: [VALUELANG] -> VALUELANG
  deriving (Show,Eq)

-- T ::= num | true | false | id | T + T | T - T | T * T | T / T 
-- |  | bind id T T | if T then T else T | T && T | T || T | T <= T | isZero T
-- lambda (id:TY) in T | (T) (T) 

data TERMLANG = Num Int
              | Plus TERMLANG TERMLANG
              | Minus TERMLANG TERMLANG
              | Mult TERMLANG TERMLANG
              | Div TERMLANG TERMLANG
              | Boolean Bool
              | And TERMLANG TERMLANG
              | Or TERMLANG TERMLANG
              | Leq TERMLANG TERMLANG
              | IsZero TERMLANG
              | If TERMLANG TERMLANG TERMLANG
              | Bind String TERMLANG TERMLANG
              | Id String
              | Lambda String TYPELANG TERMLANG
              | App TERMLANG TERMLANG
              | Array [TERMLANG]
              | Take TERMLANG TERMLANG
              | Drop TERMLANG TERMLANG
              | Length TERMLANG
              | At TERMLANG TERMLANG
                deriving (Show,Eq)

type ValueEnv = [(String, VALUELANG)]
type Cont = [(String,TYPELANG)]


evalM :: ValueEnv -> TERMLANG -> Maybe VALUELANG
evalM e (Num x) = if x<0 then Nothing else Just (NumV x)
evalM e (Plus l r) = do {
                       (NumV l') <- evalM e l;
                       (NumV r') <- evalM e r;
                       return $ NumV $ l'+r'
                     }
evalM e (Minus l r) = do {
                        (NumV l') <- evalM e l;
                        (NumV r') <- evalM e r;
                        if (l'-r') < 0
                        then Nothing
                        else return $ NumV $ l'-r'
                      }
evalM e (Mult l r) = do {
                       (NumV l') <- evalM e l;
                       (NumV r') <- evalM e r;
                       return $ NumV $ l'*r'
                     }
evalM e (Div l r) = do {
                      (NumV l') <- evalM e l;
                      (NumV r') <- evalM e r;
                      if r' == 0
                      then Nothing
                      else return $ NumV $ l' `div` r'
                    }
evalM e (Boolean b) = Just (BooleanV b)
evalM e (And l r) = do {
                      (BooleanV l') <- evalM e l;
                      (BooleanV r') <- evalM e r;
                      return $ BooleanV $ l' && r'
                    }
evalM e (Or l r) = do {
                     (BooleanV l') <- evalM e l;
                     (BooleanV r') <- evalM e r;
                     return $ BooleanV $ l' || r'
                   }
evalM e (Leq l r) = do {
                      (NumV l') <- evalM e l;
                      (NumV r') <- evalM e r;
                      return $ BooleanV $ l' <= r'
                    }
evalM e (IsZero x) = do {
                       (NumV x') <- evalM e x;
                       return $ BooleanV $ x' == 0
                     }
evalM e (If c t e') = do {
                        (BooleanV c') <- evalM e c;
                        t' <- evalM e t;
                        e'' <- evalM e e';
                        return $ if c' then t' else e''
                      }
evalM e (Bind i v b) = do {
                         v' <- evalM e v;
                         evalM ((i,v'):e) b
                       }
evalM e (Id i) = lookup i e
evalM e (Lambda i d b) = return $ ClosureV i b e
evalM e (App f a) = do {
                      (ClosureV i b j) <- evalM e f;
                      v <- evalM e a;
                      evalM ((i,v):j) b
                    }
evalM e (Array a) = do {
                      a' <- liftMaybe $ map (\a -> evalM e a) a;
                      return $ ArrayV a'
                    }
evalM e (Take n a) = do {
                       (NumV n') <- evalM e n;
                       (ArrayV a') <- evalM e a;
                       return $ ArrayV $ take n' a'
                     }
evalM e (Drop n a) = do {
                       (NumV n') <- evalM e n;
                       (ArrayV a') <- evalM e a;
                       return $ ArrayV $ drop n' a'
                     }
evalM e (Length a) = do {
                       (ArrayV a') <- evalM e a;
                       return $ NumV $ length a'
                     }
evalM e (At i a) = do {
                       (NumV i') <- evalM e i;
                       (ArrayV a') <- evalM e a;
                       return $ a' !! i'
                     }

liftMaybe :: [Maybe a] -> Maybe [a]
liftMaybe [] = Just []
liftMaybe (i:a) = do {
                    i' <- i;
                    a' <- liftMaybe a;
                    return $ i':a'
                  }


typeofM :: Cont -> TERMLANG -> Maybe TYPELANG
typeofM c (Num x) = if x>= 0 then return TNum else Nothing
typeofM c (Boolean b) = return TBool
typeofM c (Plus l r) = do {
                         TNum <- typeofM c l;
                         TNum <- typeofM c r;
                         return TNum
                       }
typeofM c (Minus l r) = do {
                          TNum <- typeofM c l;
                          TNum <- typeofM c r;
                          return TNum
                        }
typeofM c (Mult l r) = do {
                         TNum <- typeofM c l;
                         TNum <- typeofM c r;
                         return TNum
                       }
typeofM c (Div l r) = do {
                        TNum <- typeofM c l;
                        TNum <- typeofM c r;
                        return TNum
                      }
typeofM c (And l r) = do {
                        TBool <- typeofM c l;
                        TBool <- typeofM c r;
                        return TBool
                      }
typeofM c (Or l r) = do {
                       TBool <- typeofM c l;
                       TBool <- typeofM c r;
                       return TBool
                     }
typeofM c (Leq l r) = do {
                        TNum <- typeofM c l;
                        TNum <- typeofM c r;
                        return TBool
                      }
typeofM c (IsZero x) = do {
                         TNum <- typeofM c x;
                         return TBool
                       }
typeofM c (If c' t e) = do {
                          TBool <- typeofM c c';
                          t' <- typeofM c t;
                          e' <- typeofM c e;
                          if t' == e' then return t' else Nothing
                        }
typeofM c (Bind i v b) = do {
                           tv <- typeofM c v;
                           typeofM ((i,tv):c) b
                         }
typeofM c (Id i) = lookup i c
typeofM c (Lambda i d b) = do {
                             r <- typeofM ((i,d):c) b;
                             return $ d :->: r
                           }
typeofM c (App f a) = do {
                        a' <- typeofM c a;
                        d :->: r <- typeofM c f;
                        if a'==d then return r else Nothing
                      }
typeofM c (Array a) = do {
                        a' <- typeofM c $ head a;
                        return $ TArray a'
                      }
typeofM c (Take n a) = do {
                         TNum <- typeofM c n;
                         (TArray a') <- typeofM c a;
                         return $ TArray a'
                       }
typeofM c (Drop n a) = do {
                         TNum <- typeofM c n;
                         (TArray a') <- typeofM c a;
                         return $ TArray a'
                       }
typeofM c (Length a) = do {
                         TNum <- typeofM c a;
                         return TNum
                       }
typeofM c (At i a) = do {
                       TNum <- typeofM c i;
                       (TArray a') <- typeofM c a;
                       return a'
                     }

