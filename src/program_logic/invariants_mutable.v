From stdpp Require Export namespaces.
From iris.proofmode Require Import tactics.
From iris.algebra Require Import gmap.
From iris.base_logic.lib Require Export fancy_updates fupd_level.
From iris.base_logic.lib Require Import wsat.
Set Default Proof Using "Type".
Import uPred.

(* TODO: work out semantic characterization ? *)

(** Semantic Invariants *)
Definition inv_mut_def `{!invG Σ} (k: nat) (N : namespace) sch (Ps : list (iProp Σ)) : iProp Σ :=
    ∃ i, ⌜i ∈ (↑N:coPset)⌝ ∧ ownI k i sch (list_to_vec Ps).
Definition inv_mut_aux : seal (@inv_mut_def). Proof. by eexists. Qed.
Definition inv_mut {Σ i} := inv_mut_aux.(unseal) Σ i.
Definition inv_mut_eq : @inv_mut = @inv_mut_def := inv_mut_aux.(seal_eq).
Instance: Params (@inv_mut) 3 := {}.
Typeclasses Opaque inv_mut.

Definition inv_mut_full_def `{!invG Σ} (k: nat) (N : namespace) sch (Qs Ps : list (iProp Σ)) : iProp Σ :=
    ∃ i, ⌜i ∈ (↑N:coPset)⌝ ∗ ownI k i sch (list_to_vec Ps) ∗ ownI_mut k i (1/2)%Qp (list_to_vec Qs).
Definition inv_mut_full_aux : seal (@inv_mut_full_def). Proof. by eexists. Qed.
Definition inv_mut_full {Σ i} := inv_mut_full_aux.(unseal) Σ i.
Definition inv_mut_full_eq : @inv_mut_full = @inv_mut_full_def := inv_mut_full_aux.(seal_eq).
Instance: Params (@inv_mut_full) 3 := {}.
Typeclasses Opaque inv_mut_full.

Section inv_mut.
  Context `{!invG Σ}.
  Implicit Types i : positive.
  Implicit Types N : namespace.
  Implicit Types E : coPset.
  Implicit Types P Q R : iProp Σ.
  Implicit Types Ps Qs Rs : list (iProp Σ).

  Lemma inv_mut_full_acc k E N sch Qs Ps :
    ↑N ⊆ E → inv_mut_full k N sch Qs Ps -∗
    |k={E,E∖↑N}=>  bi_schema_interp k (bi_later <$> Ps) (bi_later <$> Qs) sch ∗
                  (∀ Qs', bi_schema_interp k (bi_later <$> Ps) (bi_later <$> Qs') sch -∗
                          |k={E∖↑N,E}=> inv_mut_full k N sch Qs' Ps).
  Proof.
    rewrite uPred_fupd_level_eq /uPred_fupd_level_def inv_mut_full_eq. iIntros (?).
    iDestruct 1 as (i) "[Hi [#HiP Hi_mut]]".
    iDestruct "Hi" as % ?%elem_of_subseteq_singleton.
    rewrite {1}(union_difference_L (↑ N) E) // ownE_op; last set_solver.
    rewrite {1}(union_difference_L {[ i ]} (↑ N)) // ownE_op; last set_solver.
    iIntros "(Hw & [HE HE1'] & $) !> !>".
    iDestruct (ownI_open k i with "[$Hw $HE $HiP]") as "($ & HI & HD)".
    iDestruct "HI" as (? Qs_mut) "(Hinterp&Hmut)".
    iDestruct (ownI_mut_agree with "Hi_mut Hmut") as (Hlen) "#Hequiv".
    iDestruct (bi_schema_interp_ctx_later with "[] Hequiv Hinterp") as "Hinterp".
    { iIntros. iNext. eauto. }
    rewrite ?vec_to_list_to_vec. iFrame "Hinterp".
    iIntros (Qs') "HP [Hw HE]".
    iDestruct (ownI_mut_combine  with "[$] [$]") as "Hmut". rewrite Qp_div_2.
    iMod (ownI_close_modify k _ _ (list_to_vec Ps) (list_to_vec Qs')
            with "[$Hw $HiP $Hmut $HD HP]") as "($&HE'&Hmut)".
    { rewrite ?vec_to_list_to_vec. iFrame "HP". }
    iEval (rewrite (union_difference_L (↑ N) E) // ownE_op; last set_solver).
    iEval (rewrite {1}(union_difference_L {[ i ]} (↑ N)) // ownE_op; last set_solver). iFrame.
    do 2 iModIntro. iExists _. iFrame "# ∗". iPureIntro. set_solver.
  Qed.

  Lemma inv_mut_acc k E N sch Ps :
    ↑N ⊆ E → inv_mut k N sch Ps -∗
    |k={E,E∖↑N}=> ∃ Qs, bi_schema_interp k (bi_later <$> Ps) (bi_later <$> Qs) sch ∗
                       (bi_schema_interp k (bi_later <$> Ps) (bi_later <$> Qs) sch -∗ |k={E∖↑N,E}=> True).
  Proof.
    rewrite uPred_fupd_level_eq /uPred_fupd_level_def inv_mut_eq. iIntros (?).
    iDestruct 1 as (i) "[Hi #HiP]".
    iDestruct "Hi" as % ?%elem_of_subseteq_singleton.
    rewrite {1}(union_difference_L (↑ N) E) // ownE_op; last set_solver.
    rewrite {1}(union_difference_L {[ i ]} (↑ N)) // ownE_op; last set_solver.
    iIntros "(Hw & [HE HE1'] & $) !> !>".
    iDestruct (ownI_open k i with "[$Hw $HE $HiP]") as "($ & HI & HD)".
    iDestruct "HI" as (? Qs_mut) "(Hinterp&Hmut)". iExists _.
    rewrite vec_to_list_to_vec. iFrame "Hinterp".
    iIntros "HP [Hw HE] !> !>".
    iDestruct (ownI_close k _ _ (list_to_vec Ps) with "[$Hw $HiP $Hmut $HD HP]") as "($&HE')".
    { by rewrite vec_to_list_to_vec. }
    iEval (rewrite (union_difference_L (↑ N) E) // ownE_op; last set_solver).
    iEval (rewrite {1}(union_difference_L {[ i ]} (↑ N)) // ownE_op; last set_solver). iFrame.
  Qed.

  Lemma fresh_inv_name (E : gset positive) N : ∃ i, i ∉ E ∧ i ∈ (↑N:coPset).
  Proof.
    exists (coPpick (↑ N ∖ gset_to_coPset E)).
    rewrite -elem_of_gset_to_coPset (comm and) -elem_of_difference.
    apply coPpick_elem_of=> Hfin.
    eapply nclose_infinite, (difference_finite_inv _ _), Hfin.
    apply gset_to_coPset_finite.
  Qed.

  Lemma inv_mut_alloc k N E sch Ps Qs :
    bi_schema_interp k (bi_later <$> Ps) (bi_later <$> Qs) sch -∗
    |k={E}=> inv_mut k N sch Ps ∗ inv_mut_full k N sch Qs Ps.
  Proof.
    rewrite uPred_fupd_level_eq ?inv_mut_eq ?inv_mut_full_eq. iIntros "HP [Hw $]".
    iMod (ownI_alloc (.∈ (↑N : coPset)) sch k (list_to_vec Ps) (list_to_vec Qs)
            with "[HP $Hw]")
      as (i ?) "[$ [#HI ?]]"; auto using fresh_inv_name.
    { by rewrite ?vec_to_list_to_vec. }
    do 2 iModIntro. iSplitL ""; iExists _; eauto.
  Qed.

  Global Instance inv_mut_persistent k N sch Ps : Persistent (inv_mut k N sch Ps).
  Proof. rewrite inv_mut_eq. apply _. Qed.

  (** ** Proof mode integration *)
  (* TODO *)
  (*
  Global Instance into_inv_inv N P : IntoInv (inv N P) N := {}.

  Global Instance into_acc_inv_lvl k N P E:
    IntoAcc (X := unit) (inv N P)
            (↑N ⊆ E) True (uPred_fupd_level E (E ∖ ↑N) k) (uPred_fupd_level (E ∖ ↑N) E k)
            (λ _ : (), (▷ P)%I) (λ _ : (), (▷ P)%I) (λ _ : (), None).
  Proof.
    rewrite inv_eq /IntoAcc /accessor bi.exist_unit.
    iIntros (?) "#Hinv _". iApply (fupd_level_le _ _ O); first lia.
    iMod ("Hinv" $! _ with "[//]") as "($&Hcl)".
    iModIntro. iIntros "H". iSpecialize ("Hcl" with "H").
    iApply (fupd_level_le with "Hcl"); first lia.
  Qed.

  Global Instance into_acc_inv N P E:
    IntoAcc (X := unit) (inv N P)
            (↑N ⊆ E) True (fupd E (E ∖ ↑N)) (fupd (E ∖ ↑N) E)
            (λ _ : (), (▷ P)%I) (λ _ : (), (▷ P)%I) (λ _ : (), None).
  Proof.
    rewrite inv_eq /IntoAcc /accessor bi.exist_unit.
    iIntros (?) "#Hinv _". iApply (fupd_level_fupd _ _ _ O).
    iMod ("Hinv" $! _ with "[//]") as "($&Hcl)".
    iModIntro. iIntros "H". iSpecialize ("Hcl" with "H").
    iApply (fupd_level_fupd with "Hcl").
  Qed.
   *)

End inv_mut.