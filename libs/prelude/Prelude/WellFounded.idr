||| Well-founded recursion.
|||
||| This is to let us implement some functions that don't have trivial
||| recursion patterns over datatypes, but instead are using some
||| other metric of size.
module Prelude.WellFounded

import Prelude.Nat
import Prelude.List
import Prelude.Uninhabited

%default total
%access public export

data Erased : Type -> Type where
  Erase : .(x : a) -> Erased a

unerase : Erased a -> a
unerase (Erase x) = x

||| Accessibility: some element `x` is accessible if all `y` such that
||| `rel y x` are themselves accessible.
|||
||| @ a the type of elements
||| @ rel a relation on a
||| @ x the acessible element
data Accessible : (rel : a -> a -> Type) -> (x : a) -> Type where
  ||| Accessibility
  |||
  ||| @ x the accessible element
  ||| @ rec a demonstration that all smaller elements are also accessible
  Access : (rec : (y : a) -> Erased (rel y x) -> Accessible rel y) ->
           Accessible rel x

||| A relation `rel` on `a` is well-founded if all elements of `a` are
||| acessible.
|||
||| @ rel the well-founded relation
interface WellFounded (rel : a -> a -> Type) where
  wellFounded : (x : _) -> Accessible rel x


||| A recursor over accessibility.
|||
||| This allows us to recurse over the subset of some type that is
||| accessible according to some relation.
|||
||| @ rel the well-founded relation
||| @ step how to take steps on reducing arguments
||| @ z the starting point
accRec : {rel : a -> a -> Type} ->
         (step : (x : a) -> ((y : a) -> Erased (rel y x) -> b) -> b) ->
         (z : a) -> Accessible rel z -> b
accRec step z (Access f) =
  step z $ \y, lt => accRec step y (f y lt)

||| An induction principle for accessibility.
|||
||| This allows us to recurse over the subset of some type that is
||| accessible according to some relation, producing a dependent type
||| as a result.
|||
||| @ rel the well-founded relation
||| @ step how to take steps on reducing arguments
||| @ z the starting point
accInd : {rel : a -> a -> Type} -> {P : a -> Type} ->
         (step : (x : a) -> ((y : a) -> Erased (rel y x) -> P y) -> P x) ->
         (z : a) -> Accessible rel z -> P z
accInd {P} step z (Access f) =
  step z $ \y, lt => accInd {P} step y (f y lt)


||| Use well-foundedness of a relation to write terminating operations.
|||
||| @ rel a well-founded relation
wfRec : WellFounded rel =>
        (step : (x : a) -> ((y : a) -> Erased (rel y x) -> b) -> b) ->
        a -> b
wfRec {rel} step x = accRec step x (wellFounded {rel} x)


||| Use well-foundedness of a relation to write proofs
|||
||| @ rel a well-founded relation
||| @ P the motive for the induction
||| @ step the induction step: take an element and its accessibility,
|||        and give back a demonstration of P for that element,
|||        potentially using accessibility
wfInd : WellFounded rel => {P : a -> Type} ->
        (step : (x : a) -> ((y : a) -> Erased (rel y x) -> P y) -> P x) ->
        (x : a) -> P x
wfInd {rel} step x = accInd step x (wellFounded {rel} x)

||| Interface of types with sized values.
||| The size is used for proofs of termination via accessibility.
|||
||| @ a the type whose elements can be mapped to Nat
interface Sized a where
  size : a -> Nat

Smaller : Sized a => a -> a -> Type
Smaller x y = size x `LT` size y

SizeAccessible : Sized a => a -> Type
SizeAccessible = Accessible Smaller

||| Proof of well-foundedness of `Smaller`.
||| Constructs accessibility for any given element of `a`, provided `Sized a`.
sizeAccessible : Sized a => (x : a) -> SizeAccessible x
sizeAccessible x = Access $ f (size x) (ltAccessible $ size x)
  where
    -- prove well-foundedness of `Smaller` from well-foundedness of `LT`
    f : (sizeX : Nat) -> (acc : Accessible LT sizeX)
      -> (y : a) -> Erased (size y `LT` sizeX) -> SizeAccessible y
    f Z acc y (Erase pf) = absurd pf
    f (S n) (Access acc) y (Erase (LTESucc yLEx))
      = Access (\z, (Erase zLTy) =>
          f n (acc n $ Erase (LTESucc lteRefl)) z (Erase $ lteTransitive zLTy yLEx)
        )

    ||| LT is a well-founded relation on numbers
    ltAccessible : (n : Nat) -> Accessible LT n
    ltAccessible n = Access (\v, prf => ltAccessible' {n'=v} n prf)
      where
        ltAccessible' : (m : Nat) -> Erased (LT n' m) -> Accessible LT n'
        ltAccessible' Z (Erase x) = absurd x
        ltAccessible' (S k) (Erase $ LTESucc x)
            = Access (\val, (Erase p) => ltAccessible' k (Erase $ lteTransitive p x))

||| Strong induction principle for sized types.
sizeInd : Sized a
  => {P : a -> Type}
  -> (step : (x : a) -> ((y : a) -> Erased (Smaller y x) -> P y) -> P x)
  -> (z : a)
  -> P z
sizeInd step z = accInd step z (sizeAccessible z)

||| Strong recursion principle for sized types.
sizeRec : Sized a
  => (step : (x : a) -> ((y : a) -> Erased (Smaller y x) -> b) -> b)
  -> (z : a)
  -> b
sizeRec step z = accRec step z (sizeAccessible z)


implementation Sized Nat where
  size = \x => x

implementation Sized (List a) where
  size = length
