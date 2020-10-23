From RecordUpdate Require Import RecordSet.
Import RecordSetNotations.

From iris.algebra Require Import numbers.

From Perennial.Helpers Require Import Transitions NamedProps Map.
From Perennial.program_proof Require Import proof_prelude.
From Perennial.algebra Require Import deletable_heap log_heap.

From Goose.github_com.mit_pdos.goose_nfsd Require Import txn.
From Goose.github_com.mit_pdos.goose_nfsd Require Import wal.
From Perennial.program_proof Require Import wal.specs wal.lib wal.heapspec addr.addr_proof buf.buf_proof disk_lib.
From Perennial.program_proof Require Export txn.invariant.
From Perennial.goose_lang.lib Require Import slice.typed_slice.

Remove Hints fractional.into_sep_fractional : typeclass_instances.

Section goose_lang.
Context `{!txnG Σ}.

Implicit Types (s : Slice.t) (γ: @txn_names Σ).

Theorem wp_txn_Load l γ dinit a v :
  {{{ is_txn l γ dinit ∗
      mapsto_txn γ a v
  }}}
    Txn__Load #l (addr2val a) #(bufSz (projT1 v))
  {{{ (bufptr : loc) b, RET #bufptr;
      is_buf bufptr a b ∗
      ⌜ b.(bufDirty) = false ⌝ ∗
      ⌜ existT b.(bufKind) b.(bufData) = v ⌝ ∗
      mapsto_txn γ a v
  }}}.
Proof using txnG0 Σ.
  iIntros (Φ) "(#Htxn & Hstable) HΦ".
  iNamed "Htxn".
  iNamed "Hstable".

  wp_call.
  wp_loadField.

  wp_call.

  wp_apply (wp_Walog__ReadMem _ (λ mb,
    "Hmapsto_log" ∷ mapsto_cur a v ∗
    "Hmapsto_meta" ∷ mapsto a 1 γm ∗
    match mb with
    | Some b =>
      "Hmod_frag" ∷ ghost_var γm (1/2) true ∗
      "%Hv" ∷ ⌜ is_bufData_at_off b a.(addrOff) (projT2 v) ∧ valid_addr a ⌝
    | None =>
      "Hmod_frag" ∷ ghost_var γm (1/2) false
    end)%I with "[$Hiswal Hmapsto_log Hmapsto_meta Hmod_frag]").
  {
    iApply (wal_heap_readmem (⊤ ∖ ↑walN ∖ ↑invN) with "[Hmapsto_log Hmapsto_meta Hmod_frag]").

    iInv invN as ">Hinv_inner" "Hinv_closer".
    iNamed "Hinv_inner".
    iModIntro.

    iDestruct (log_heap_valid_cur with "Hlogheapctx Hmapsto_log") as "%Hlogvalid".
    iDestruct (gen_heap_valid with "Hmetactx Hmapsto_meta") as "%Hmetavalid".

    eapply gmap_addr_by_block_lookup in Hlogvalid; destruct Hlogvalid.
    eapply gmap_addr_by_block_lookup in Hmetavalid; destruct Hmetavalid.
    intuition idtac.

    iDestruct (big_sepM2_lookup_acc with "Hheapmatch") as "[Hblockmatch Hheapmatch]"; eauto.
    iNamed "Hblockmatch".
    iExists _, _; iFrame "Htxn_hb".

    iNamed "Htxn_in_hb".
    iIntros (mb) "Hrmq".
    destruct mb; rewrite /=.

    {
      iDestruct "Hrmq" as "[Hrmq %]".
      iDestruct (big_sepM2_lookup_acc with "Htxn_in_hb") as "[Hoff Htxn_in_hb]"; eauto.
      iNamed "Hoff".
      iDestruct ("Htxn_in_hb" with "[Hoff_own]") as "Htxn_in_hb"; eauto.
      iDestruct ("Hheapmatch" with "[Hrmq Htxn_in_hb]") as "Hheapmatch".
      { iExists _, _, _. iFrame. done. }
      iDestruct ("Hinv_closer" with "[-Hmapsto_log Hmapsto_meta Hmod_frag]") as "Hinv_closer".
      {
        iModIntro.
        iExists _, _, _. iFrame.
      }

      iMod "Hinv_closer".
      iModIntro. iFrame.
      iPureIntro.
      rewrite /bufDataT_in_block in Hoff_in_block. subst. intuition eauto.
    }

    {
      iDestruct (big_sepM2_delete with "Htxn_in_hb") as "[Hoff Htxn_in_hb]"; eauto.
      iNamed "Hoff".
      iMod (ghost_var_update_halves false with "Hoff_own Hmod_frag") as "[Hoff_own Hmod_frag]".

      iDestruct ("Hinv_closer" with "[-Hmapsto_log Hmapsto_meta Hmod_frag]") as "Hinv_closer".
      {
        iModIntro.
        iExists _, _, _. iFrame.
        iApply "Hheapmatch".
        iExists _, _, _.
        iFrame.
        iSplitR; first by done.
        iDestruct (big_sepM2_mono with "Htxn_in_hb") as "Htxn_in_hb".
        2: {
          iDestruct (big_sepM2_insert_delete with "[$Htxn_in_hb Hoff_own]") as "Htxn_in_hb".
          2: rewrite -> (insert_id x) by eauto.
          2: rewrite -> (insert_id x0) by eauto.
          2: iApply "Htxn_in_hb".
          iExists _. iFrame.
          iSplit; first by done.
          iPureIntro. intros.
          rewrite take_nil /=. eauto.
        }

        iIntros (k y1 y2 Hky1 Hky2) "H".
        iNamed "H". iExists _. iFrame.
        iSplit; first by done.
        iPureIntro. intros.
        destruct modifiedSinceInstall0; eauto.
        intros. rewrite take_nil /=. eauto.
      }

      iMod "Hinv_closer".
      iModIntro.
      iFrame.
    }
  }

  iIntros (ok bl) "Hres".
  destruct ok.
  {
    (* Case 1: hit in the cache *)

    iDestruct "Hres" as (b) "[Hisblock Hres]".
    iNamed "Hres".
    wp_pures.
    rewrite /is_block.
    wp_apply (wp_MkBufLoad with "[$Hisblock]"); eauto.
    iIntros (bufptr) "Hbuf".
    wp_pures.
    iApply "HΦ". iFrame.
    rewrite /=.
    iSplitR; first done.
    destruct v. iSplitR; first done.
    iExists _. iFrame.
  }

  (* Case 2: missed in cache *)
  iNamed "Hres".
  wp_pures.

  wp_apply (wp_Walog__ReadInstalled _
    (λ b,
      "Hmapsto_log" ∷ mapsto_cur a v ∗
      "Hmapsto_meta" ∷ mapsto a 1 γm ∗
      "%Hv" ∷ ⌜ is_bufData_at_off b a.(addrOff) (projT2 v) ∧ valid_addr a ⌝ ∗
      "Hmod_frag" ∷ ghost_var γm (1/2) true
    )%I
    with "[$Hiswal Hmapsto_log Hmapsto_meta Hmod_frag]").
  {
    iSplitR.
    { admit. }

    iApply (wal_heap_readinstalled (⊤ ∖ ↑walN ∖ ↑invN) with "[Hmapsto_log Hmapsto_meta Hmod_frag]").

    iInv invN as ">Hinv_inner" "Hinv_closer".
    iNamed "Hinv_inner".
    iModIntro.

    iDestruct (log_heap_valid_cur with "Hlogheapctx Hmapsto_log") as "%Hlogvalid".
    iDestruct (gen_heap_valid with "Hmetactx Hmapsto_meta") as "%Hmetavalid".

    eapply gmap_addr_by_block_lookup in Hlogvalid; destruct Hlogvalid.
    eapply gmap_addr_by_block_lookup in Hmetavalid; destruct Hmetavalid.
    intuition idtac.

    iDestruct (big_sepM2_lookup_acc with "Hheapmatch") as "[Hblockmatch Hheapmatch]"; eauto.
    iNamed "Hblockmatch".
    iExists _, _; iFrame "Htxn_hb".
    iNamed "Htxn_in_hb".

    iIntros (b) "Hriq".
    iDestruct "Hriq" as "[Hriq %]".

    iDestruct (big_sepM2_lookup_acc with "Htxn_in_hb") as "[Hoff Htxn_in_hb]"; eauto.
    iNamed "Hoff".
    iDestruct (ghost_var_agree with "Hoff_own Hmod_frag") as %->.
    iMod (ghost_var_update_halves true with "Hoff_own Hmod_frag") as "[Hoff_own Hmod_frag]".
    iDestruct ("Htxn_in_hb" with "[Hoff_own]") as "Htxn_in_hb"; eauto.
    iDestruct ("Hheapmatch" with "[Hriq Htxn_in_hb]") as "Hheapmatch".
    { iExists _, _, _. iFrame. done. }

    iFrame.
    iDestruct ("Hinv_closer" with "[-]") as "Hinv_closer".
    {
      iModIntro.
      iExists _, _, _.
      iFrame.
    }

    iMod "Hinv_closer".
    iModIntro.
    iPureIntro.

    apply elem_of_list_lookup_1 in H0.
    destruct H0 as [prefix H0].
    specialize (Hoff_prefix_in_block prefix).
    erewrite latest_update_take_some in Hoff_prefix_in_block by eauto.
    rewrite /bufDataT_in_block in Hoff_prefix_in_block.
    intuition eauto.
  }

  iIntros (bslice) "Hres".
  iDestruct "Hres" as (b) "[Hb Hres]".
  iNamed "Hres".
  wp_pures.
  rewrite /is_block.
  wp_apply (wp_MkBufLoad with "[$Hb]"); eauto.
  iIntros (bufptr) "Hbuf".
  wp_pures.
  iApply "HΦ".
  iFrame.
  iSplitR; first done.
  destruct v.
  iSplitR; first done.
  iExists _. iFrame.
Admitted.

End goose_lang.