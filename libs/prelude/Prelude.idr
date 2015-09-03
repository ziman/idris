module Prelude

import public Builtins
import public IO

import public Prelude.Algebra
import public Prelude.Basics
import public Prelude.Bool
import public Prelude.Classes
import public Prelude.Cast
import public Prelude.Nat
import public Prelude.List
import public Prelude.Maybe
import public Prelude.Monad
import public Prelude.Applicative
import public Prelude.Foldable
import public Prelude.Functor
import public Prelude.Either
import public Prelude.Strings
import public Prelude.Chars
import public Prelude.Traversable
import public Prelude.Bits
import public Prelude.Uninhabited
import public Prelude.Pairs
import public Prelude.Stream
import public Prelude.Providers
import public Prelude.Show
import public Prelude.Interactive
import public Prelude.File
import public Decidable.Equality
import public Language.Reflection
import public Language.Reflection.Errors

%access public
%default total

-- Things that can't be elsewhere for import cycle reasons
decAsBool : Dec p -> Bool
decAsBool (Yes _) = True
decAsBool (No _)  = False


---- Functor instances

instance Functor PrimIO where
    map f io = prim_io_bind io (prim_io_return . f)

instance Functor Maybe where
    map f (Just x) = Just (f x)
    map f Nothing  = Nothing

instance Functor (Either e) where
    map f (Left l) = Left l
    map f (Right r) = Right (f r)

---- Applicative instances

instance Applicative PrimIO where
    pure = prim_io_return

    am <*> bm = prim_io_bind am (\f => prim_io_bind bm (prim_io_return . f))

instance Applicative Maybe where
    pure = Just

    (Just f) <*> (Just a) = Just (f a)
    _        <*> _        = Nothing

instance Applicative (Either e) where
    pure = Right

    (Left a) <*> _          = Left a
    (Right f) <*> (Right r) = Right (f r)
    (Right _) <*> (Left l)  = Left l

instance Applicative List where
    pure x = [x]

    fs <*> vs = concatMap (\f => map f vs) fs

---- Alternative instances

instance Alternative Maybe where
    empty = Nothing

    (Just x) <|> _ = Just x
    Nothing  <|> v = v

instance Alternative List where
    empty = []

    (<|>) = (++)

---- Monad instances

instance Monad PrimIO where
    b >>= k = prim_io_bind b k

instance Monad Maybe where
    Nothing  >>= k = Nothing
    (Just x) >>= k = k x

instance Monad (Either e) where
    (Left n) >>= _ = Left n
    (Right r) >>= f = f r

instance Monad List where
    m >>= f = concatMap f m

---- Traversable instances

instance Traversable Maybe where
    traverse f Nothing = pure Nothing
    traverse f (Just x) = [| Just (f x) |]

instance Traversable List where
    traverse f [] = pure List.Nil
    traverse f (x::xs) = [| List.(::) (f x) (traverse f xs) |]

---- some mathematical operations
---- XXX this should probably go some place else,
pow : (Num a) => a -> Nat -> a
pow x Z = 1
pow x (S n) = x * (pow x n)

---- Ranges

natRange : Nat -> List Nat
natRange n = List.reverse (go n)
  where go Z = []
        go (S n) = n :: go n

-- predefine Nat versions of Enum, so we can use them in the default impls
total natEnumFromThen : Nat -> Nat -> Stream Nat
natEnumFromThen n inc = n :: natEnumFromThen (inc + n) inc
total natEnumFromTo : Nat -> Nat -> List Nat
natEnumFromTo n m = map (plus n) (natRange (minus (S m) n))
total natEnumFromThenTo : Nat -> Nat -> Nat -> List Nat
natEnumFromThenTo _ Z       _ = []
natEnumFromThenTo n (S inc) m = map (plus n . (* (S inc))) (natRange (S (divNatNZ (minus m n) (S inc) SIsNotZ)))

class Enum a where
  total pred : a -> a
  total succ : a -> a
  succ e = fromNat (S (toNat e))
  total toNat : a -> Nat
  total fromNat : Nat -> a
  total enumFrom : a -> Stream a
  enumFrom n = n :: enumFrom (succ n)
  total enumFromThen : a -> a -> Stream a
  enumFromThen x y = map fromNat (natEnumFromThen (toNat x) (toNat y))
  total enumFromTo : a -> a -> List a
  enumFromTo x y = map fromNat (natEnumFromTo (toNat x) (toNat y))
  total enumFromThenTo : a -> a -> a -> List a
  enumFromThenTo x1 x2 y = map fromNat (natEnumFromThenTo (toNat x1) (toNat x2) (toNat y))

instance Enum Nat where
  pred n = Nat.pred n
  succ n = S n
  toNat x = id x
  fromNat x = id x
  enumFromThen x y = natEnumFromThen x y
  enumFromThenTo x y z = natEnumFromThenTo x y z
  enumFromTo x y = natEnumFromTo x y

instance Enum Integer where
  pred n = n - 1
  succ n = n + 1
  toNat n = cast n
  fromNat n = cast n
  enumFromThen n inc = n :: enumFromThen (inc + n) inc
  enumFromTo n m = if n <= m
                   then go (natRange (S (cast {to = Nat} (m - n))))
                   else []
    where go : List Nat -> List Integer
          go [] = []
          go (x :: xs) = n + cast x :: go xs
  enumFromThenTo _ 0   _ = []
  enumFromThenTo n inc m = go (natRange (S (divNatNZ (fromInteger (abs (m - n))) (S (fromInteger ((abs inc) - 1))) SIsNotZ)))
    where go : List Nat -> List Integer
          go [] = []
          go (x :: xs) = n + (cast x * inc) :: go xs

instance Enum Int where
  pred n = n - 1
  succ n = n + 1
  toNat n = cast n
  fromNat n = cast n
  enumFromTo n m =
    if n <= m
       then go [] (cast {to = Nat} (m - n)) m
       else []
       where
         go : List Int -> Nat -> Int -> List Int
         go acc Z     m = m :: acc
         go acc (S k) m = go (m :: acc) k (m - 1)
  enumFromThen n inc = n :: enumFromThen (inc + n) inc
  enumFromThenTo _ 0   _ = []
  enumFromThenTo n inc m = go (natRange (S (divNatNZ (cast {to=Nat} (abs (m - n))) (S (cast {to=Nat} ((abs inc) - 1))) SIsNotZ)))
    where go : List Nat -> List Int
          go [] = []
          go (x :: xs) = n + (cast x * inc) :: go xs

syntax "[" [start] ".." [end] "]"
     = enumFromTo start end
syntax "[" [start] "," [next] ".." [end] "]"
     = enumFromThenTo start (next - start) end

syntax "[" [start] ".." "]"
     = enumFrom start
syntax "[" [start] "," [next] ".." "]"
     = enumFromThen start (next - start)

---- More utilities

curry : ((a, b) -> c) -> a -> b -> c
curry f a b = f (a, b)

uncurry : (a -> b -> c) -> (a, b) -> c
uncurry f (a, b) = f a b

namespace JSNull
  ||| Check if a foreign pointer is null
  partial
  nullPtr : Ptr -> JS_IO Bool
  nullPtr p = do ok <- foreign FFI_JS "isNull" (Ptr -> JS_IO Int) p
                 return (ok /= 0)

  ||| Check if a supposed string was actually a null pointer
  partial
  nullStr : String -> JS_IO Bool
  nullStr p = do ok <- foreign FFI_JS "isNull" (String -> JS_IO Int) p
                 return (ok /= 0)


||| Pointer equality
eqPtr : Ptr -> Ptr -> IO Bool
eqPtr x y = do eq <- foreign FFI_C "idris_eqPtr" (Ptr -> Ptr -> IO Int) x y
               return (eq /= 0)

||| Loop while some test is true
|||
||| @ test the condition of the loop
||| @ body the loop body
partial -- obviously
while : (test : IO' l Bool) -> (body : IO' l ()) -> IO' l ()
while t b = do v <- t
               if v then do b
                            while t b
                    else return ()

------- Some error rewriting

%language ErrorReflection
  
private
cast_part : TT -> ErrorReportPart
cast_part (P Bound n t) = TextPart "unknown type"
cast_part x = TermPart x
  
%error_handler
cast_error : Err -> Maybe (List ErrorReportPart)
cast_error (CantResolve `(Cast ~x ~y))
     = Just [TextPart "Can't cast from",
             cast_part x,
             TextPart "to",
             cast_part y]
cast_error _ = Nothing

%error_handler
num_error : Err -> Maybe (List ErrorReportPart)
num_error (CantResolve `(Num ~x))
     = Just [TermPart x, TextPart "is not a numeric type"]
num_error _ = Nothing

