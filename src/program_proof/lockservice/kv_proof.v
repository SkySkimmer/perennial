From Coq.Structures Require Import OrdersTac.
From stdpp Require Import gmap.
From iris.algebra Require Import numbers.
From iris.program_logic Require Export weakestpre.
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.
From Perennial.goose_lang Require Import notation.
From Perennial.program_proof Require Import proof_prelude.
From RecordUpdate Require Import RecordUpdate.
From Perennial.algebra Require Import auth_map.
From Perennial.goose_lang.lib Require Import lock.
From Perennial.Helpers Require Import NamedProps.
From Perennial.Helpers Require Import ModArith.
From Perennial.program_proof.lockservice Require Import lockservice rpc common_proof nondet rpc.

Record kvservice_names := KVserviceGN {
  ks_rpcGN : rpc_names;
  ks_kvMapGN : gname;
}.

Class kvserviceG Σ := KVserviceG {
  ls_rpcG :> rpcG Σ u64; (* RPC layer ghost state *)
  ls_kvMapG :> mapG Σ u64 u64; (* [γkv]: tracks the state of the KV server *logically* *)
}.

Section kv_proof.
Context `{!heapG Σ, !kvserviceG Σ}.

Implicit Types (γ : kvservice_names).

Local Notation "k [[ γ ]]↦ '_'" := (∃ v, k [[γ]]↦ v)%I
(at level 20, format "k  [[ γ ]]↦ '_'") : bi_scope.

Definition Get_Pre γ va : RPCValC -> iProp Σ := (λ args, args.1 [[γ.(ks_kvMapGN)]]↦ va)%I.
Definition Get_Post γ va : RPCValC -> u64 -> iProp Σ := λ args v, (⌜v = va⌝ ∗ args.1 [[γ.(ks_kvMapGN)]]↦ v)%I.

Definition Put_Pre γ : RPCValC -> iProp Σ := (λ args, args.1 [[γ.(ks_kvMapGN)]]↦ _)%I.
Definition Put_Post γ : RPCValC -> u64 -> iProp Σ := (λ args _, args.1 [[γ.(ks_kvMapGN)]]↦ args.2.1)%I.

Definition KVServer_own_core γ (srv:loc) : iProp Σ :=
  ∃ (kvs_ptr:loc) (kvsM:gmap u64 u64),
  "HlocksOwn" ∷ srv ↦[KVServer.S :: "kvs"] #kvs_ptr
∗ "HkvsMap" ∷ is_map (kvs_ptr) kvsM
∗ "Hkvctx" ∷ map_ctx γ.(ks_kvMapGN) 1 kvsM
.

(* FIXME: this is currently just a placeholder *)
Definition own_kvclerk γ ck_ptr srv : iProp Σ :=
  ∃ (cl_ptr:loc),
   "Hcl_ptr" ∷ ck_ptr ↦[KVClerk.S :: "client"] #cl_ptr ∗
   "Hprimary" ∷ ck_ptr ↦[KVClerk.S :: "primary"] #srv ∗
   "Hcl" ∷ own_rpcclient cl_ptr γ.(ks_rpcGN).

Definition is_kvserver γ (srv:loc) : iProp Σ :=
  ∃ (sv:loc),
  "#Hsv" ∷ readonly (srv ↦[KVServer.S :: "sv"] #sv) ∗
  "#His_rpc" ∷ is_rpcserver sv γ.(ks_rpcGN) (KVServer_own_core γ srv)
.

Lemma put_core_spec γ (srv:loc) args :
{{{ 
     KVServer_own_core γ srv ∗ Put_Pre γ args
}}}
  KVServer__put_core #srv (into_val.to_val args)
{{{
   RET #0; KVServer_own_core γ srv
      ∗ Put_Post γ args 0
}}}.
Proof.
  iIntros (Φ) "[Hksown Hpre] Hpost".
  wp_lam.
  wp_pures.
  iNamed "Hksown".
  wp_pures.
  wp_loadField.
  wp_apply (wp_MapInsert with "HkvsMap"); eauto; iIntros "HkvsMap".
  iDestruct "Hpre" as (v') "Hpre".
  iMod (map_update with "Hkvctx Hpre") as "[Hkvctx Hptsto]".
  wp_seq.
  iApply "Hpost".
  iFrame. iExists _, _; iFrame.
Qed.

Lemma get_core_spec (srv:loc) args (va:u64) γ :
{{{ 
     KVServer_own_core γ srv ∗ Get_Pre γ va args
}}}
  KVServer__get_core #srv (into_val.to_val args)%V
{{{
   r, RET #r; KVServer_own_core γ srv ∗
   Get_Post γ va args r
}}}.
Proof.
  iIntros (Φ) "[Hksown Hpre] Hpost".
  wp_lam.
  wp_pures.
  iNamed "Hksown".
  wp_pures.
  wp_loadField.
  wp_apply (wp_MapGet with "HkvsMap").
  iIntros (v ok) "[% HkvsMap]".
  iDestruct (map_valid with "Hkvctx Hpre") as %Hvalid.
  assert (va = v) as ->.
  {
    rewrite /map_get in H.
    rewrite ->bool_decide_true in H; eauto.
    simpl in H.
    injection H as H.
    rewrite /default in H.
    rewrite Hvalid in H.
    done.
  }
  wp_pures.
  iApply "Hpost".
  iFrame.
  iSplit; last done. iExists _, _; iFrame.
Qed.

Lemma KVServer__Get_spec srv va γ :
is_kvserver γ srv -∗
{{{
    True
}}}
    KVServer__Get #srv
{{{ (f:goose_lang.val), RET f;
        is_rpcHandler f γ.(ks_rpcGN) (Get_Pre γ va) (Get_Post γ va)
}}}.
Proof.
  iIntros "#Hks".
  iIntros (Φ) "!# Hpre Hpost".
  wp_lam.
  wp_pures.
  iApply "Hpost".

  unfold is_rpcHandler.
  iIntros.
  iIntros (Ψ) "!# Hpre Hpost".
  iNamed "Hpre".
  wp_lam. wp_pures.
  iNamed "Hks".
  wp_loadField.
  wp_apply (RPCServer__HandleRequest_spec with "[] [Hreply]"); iFrame "# ∗".
  iModIntro. iIntros (Θ).
  iIntros "Hpre Hpost".
  wp_lam.
  wp_apply (get_core_spec with "[Hpre]"); eauto.
Qed.

Lemma KVClerk__Get_spec (kck ksrv:loc) (key va:u64) γ  :
is_kvserver γ ksrv -∗
{{{
     own_kvclerk γ kck ksrv ∗ (key [[γ.(ks_kvMapGN)]]↦ va)
}}}
  KVClerk__Get #kck #key
{{{
     v, RET #v; ⌜v = va⌝ ∗ own_kvclerk γ kck ksrv ∗ (key [[γ.(ks_kvMapGN)]]↦ va )
}}}.
Proof.
  iIntros "#Hserver" (Φ) "!# (Hclerk & Hpre) Hpost".
  wp_lam.
  wp_pures. 
  iNamed "Hclerk".
  repeat wp_loadField.
  wp_apply KVServer__Get_spec; first eauto.
  iIntros (f) "#Hfspec".
  wp_loadField.
  wp_apply (RPCClient__MakeRequest_spec _ cl_ptr (key, (U64(0), ())) γ.(ks_rpcGN) with "[] [Hpre Hcl]"); eauto.
  {
    iNamed "Hserver". iNamed "His_rpc". iFrame "# ∗".
  }
  iIntros (v) "Hretv".
  iDestruct "Hretv" as "[Hrpcclient HcorePost]".
  iApply "Hpost".
  iDestruct "HcorePost" as (->) "Hkv".
  iSplit; first done.
  iFrame "Hkv".
  iExists _; iFrame.
Qed.

Lemma KVServer__Put_spec srv γ :
is_kvserver γ srv -∗
{{{
    True
}}}
    KVServer__Put #srv
{{{ (f:goose_lang.val), RET f;
        is_rpcHandler f γ.(ks_rpcGN) (Put_Pre γ) (Put_Post γ)
}}}.
Proof.
  iIntros "#Hks".
  iIntros (Φ) "!# Hpre Hpost".
  wp_lam.
  wp_pures.
  iApply "Hpost".

  unfold is_rpcHandler.
  iIntros.
  iIntros (Ψ) "!# Hpre Hpost".
  iNamed "Hpre".
  wp_lam. wp_pures.
  iNamed "Hks".
  wp_loadField.
  wp_apply (RPCServer__HandleRequest_spec with "[] [Hreply]"); iFrame "# ∗".
  iModIntro. iIntros (Θ).
  iIntros "Hpre Hpost".
  wp_lam.
  wp_apply (put_core_spec with "[Hpre]"); eauto.
Qed.
(* TODO: see if any more repetition can be removed *)


Lemma KVClerk__Put_spec (kck srv:loc) (key va:u64) γ :
is_kvserver γ srv -∗
{{{
     own_kvclerk γ kck srv ∗ (key [[γ.(ks_kvMapGN)]]↦ _ )
}}}
  KVClerk__Put #kck #key #va
{{{
     RET #();
     own_kvclerk γ kck srv ∗ (key [[γ.(ks_kvMapGN)]]↦ va )
}}}.
Proof.
  iIntros "#Hserver" (Φ) "!# (Hclerk & Hpre) Hpost".
  wp_lam.
  wp_pures. 
  iNamed "Hclerk".
  repeat wp_loadField.
  wp_apply KVServer__Put_spec; first eauto.
  iIntros (f) "#Hfspec".
  wp_loadField.
  wp_apply (RPCClient__MakeRequest_spec _ cl_ptr (key, (va, ())) γ.(ks_rpcGN) with "[] [Hpre Hcl]"); eauto.
  {
    iNamed "Hserver". iNamed "His_rpc". iFrame "# ∗".
  }
  iIntros (v) "Hretv".
  iDestruct "Hretv" as "[Hrpcclient HcorePost]".
  wp_seq.
  iApply "Hpost".
  iFrame.
  iExists _; iFrame.
Qed.

Definition kvserver_cid_token γ cid :=
  RPCClient_own γ.(ks_rpcGN) cid 1.

Lemma MakeKVServer_spec :
  {{{ True }}}
    MakeKVServer #()
  {{{ γ srv, RET #srv;
    is_kvserver γ srv ∗ [∗ set] cid ∈ fin_to_set u64, kvserver_cid_token γ cid
  }}}.
Proof.
  iIntros (Φ) "_ HΦ". wp_lam.
  iMod make_rpc_server as (γrpc) "(#is_server & server_own & cli_tokens)"; first done.
  iMod (map_init (∅ : gmap u64 u64)) as (γkv) "Hγkv".
  set (γ := KVserviceGN γrpc γkv) in *.
  iApply wp_fupd.

  wp_apply wp_allocStruct; first by eauto.
  iIntros (l) "Hl". wp_pures.
  iDestruct (struct_fields_split with "Hl") as "(l_sv & l_locks & _)".
  wp_apply (wp_NewMap u64 (t:=uint64T)). iIntros (kvs) "Hkvs".
  wp_storeField.
  wp_apply (MakeRPCServer_spec (KVServer_own_core γ l) with "[$server_own $is_server l_locks Hγkv Hkvs]").
  { iExists _, _. iFrame. }
  iIntros (sv) "#Hsv".
  wp_storeField.
  iApply ("HΦ" $! γ).
  iFrame "cli_tokens".
  iExists sv. iFrame "#".
  by iMod (readonly_alloc_1 with "l_sv") as "$".
Qed.
(* TODO: return all of the ptsto's here; update KVServer_own_core so it has map_ctx bigger than the physical map *)


Lemma MakeKVClerk_spec γ (srv : loc) (cid : u64) :
  {{{ is_kvserver γ srv ∗ kvserver_cid_token γ cid }}}
    MakeKVClerk #srv #cid
  {{{ ck, RET #ck; own_kvclerk γ ck srv }}}.
Proof.
  iIntros (Φ) "[#Hserver Hcid] HΦ". wp_lam.
  rewrite /kvserver_cid_token /own_kvclerk.
  iApply wp_fupd.

  wp_apply wp_allocStruct; first by eauto.
  iIntros (l) "Hl". wp_pures.
  iDestruct (struct_fields_split with "Hl") as "(l_primary & l_client & _)".
  wp_storeField.
  wp_apply (MakeRPCClient_spec with "Hcid").
  iIntros (cl) "Hcl".
  wp_storeField.
  iApply "HΦ". iExists _.
  by iFrame.
Qed.


End kv_proof.
