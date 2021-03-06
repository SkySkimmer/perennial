From Perennial.program_logic Require Export crash_weakestpre.
Set Default Proof Using "Type".

(** Sugar for HoCAP-style logically atomic specs.
[Pa] is what the client *gets* right before the linearization point, and [Qa]
is what they have to prove to complete linearization.

We use [<<{] becazse [<<<] is already used in Iris for TaDa-style logically
atomic triples.

TODO: add versions without the ∀∀ binder.
And maybe versions with an ∃∃ binder in front of [Qa]? *)

Notation "'{{{' P } } } '<<{' ∀∀ x1 .. xn , Pa '}>>' e @ s ; k ; E1 <<{ Qa '}>>' {{{ z1 .. zn , 'RET' pat ; Q } } }" :=
  (□ ∀ Φ Φc,
      P -∗
      <disc> ▷ Φc (* crash condition before lin.point *) ∧
        ▷ (∀ x1, .. (∀ xn, Pa -∗ |NC={⊤}=> Qa ∗
          (<disc> ▷ Φc (* crash condition after lin.point *) ∧
           ∀ z1, .. (∀ zn, Q -∗ Φ pat%V) .. )) .. ) -∗
      WPC e @ s; k; E1 {{ Φ }} {{ Φc }})%I
    (at level 20, x1 closed binder, xn closed binder, z1 closed binder, zn closed binder,
     format "'[hv' {{{  P  } } }  '/'  <<{  ∀∀  x1  ..  xn ,  Pa }>>  '/  ' e  '/' @  s ; k ;  E1 '/' <<{ Qa }>> '/' {{{  z1  ..  zn ,  RET  pat ;  Q  } } } ']'") : bi_scope.

Notation "'{{{' P } } } '<<{' ∀∀ x1 .. xn , Pa '}>>' e @ s ; k ; E1 <<{ Qa '}>>' {{{ 'RET' pat ; Q } } }" :=
  (□ ∀ Φ Φc,
      P -∗
      <disc> ▷ Φc (* crash condition before lin.point *) ∧
        ▷ (∀ x1, .. (∀ xn, Pa -∗ |NC={⊤}=> Qa ∗
          (<disc> ▷ Φc (* crash condition after lin.point *) ∧
          (Q -∗ Φ pat%V) )) .. ) -∗
      WPC e @ s; k; E1 {{ Φ }} {{ Φc }})%I
    (at level 20, x1 closed binder, xn closed binder,
     format "'[hv' {{{  P  } } }  '/'  <<{  ∀∀  x1  ..  xn ,  Pa }>>  '/  ' e  '/' @  s ; k ;  E1 '/' <<{ Qa }>> '/' {{{  RET  pat ;  Q  } } } ']'") : bi_scope.
