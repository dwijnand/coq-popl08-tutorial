(**************************************************************)
(* FSetDecide.v                                               *)
(*                                                            *)
(* Author: Aaron Bohannon                                     *)
(**************************************************************)

(** This file implements a decision procedure for a certain
    class of propositions involving finite sets.  *)

Require Import FSets.

Module Decide (Import M : S).

(** * Overview
    This functor defines the tactic [fsetdec], which will
    solve any valid goal of the form
<<
    forall s1 ... sn,
    forall x1 ... xm,
    P1 -> ... -> Pk -> P
>>
    where [P]'s are defined by the grammar:
<<

P ::=
| Q
| Empty F
| Subset F F'
| Equal F F'

Q ::=
| E.eq X X'
| In X F
| Q /\ Q'
| Q \/ Q'
| Q -> Q'
| Q <-> Q'
| ~ Q
| True
| False

F ::=
| S
| empty
| singleton X
| add X F
| remove X F
| union F F'
| inter F F'
| diff F F'

X ::= x1 | ... | xm
S ::= s1 | ... | sn

>>

The tactic will also work on some goals that vary slightly from
the above form:
- The variables and hypotheses may be mixed in any order and may
  have already been introduced into the context.  Moreover,
  there may be additional, unrelated hypotheses mixed in (these
  will be ignored).
- A conjunction of hypotheses will be handled as easily as
  separate hypotheses, i.e., [P1 /\ P2 -> P] can be solved iff
  [P1 -> P2 -> P] can be solved.
- [fsetdec] should solve any goal if the FSet-related hypotheses
  are contradictory.
- [fsetdec] will first perform any necessary zeta and beta
  reductions and will invoke [subst] to eliminate any Coq
  equalities between finite sets or their elements.
- If [E.eq] is convertible with Coq's equality, it will not
  matter which one is used in the hypotheses or conclusion.
- The tactic can solve goals where the finite sets or set
  elements are expressed by Coq terms that are more complicated
  than variables.  However, non-local definitions are not
  expanded, and Coq equalities between non-variable terms are
  not used.  For example, this goal will be solved:
<<
    forall (f : t -> t),
    forall (g : elt -> elt),
    forall (s1 s2 : t),
    forall (x1 x2 : elt),
    Equal s1 (f s2) ->
    E.eq x1 (g (g x2)) ->
    In x1 s1 ->
    In (g (g x2)) (f s2)
>>
  This one will not be solved:
<<
    forall (f : t -> t),
    forall (g : elt -> elt),
    forall (s1 s2 : t),
    forall (x1 x2 : elt),
    Equal s1 (f s2) ->
    E.eq x1 (g x2) ->
    In x1 s1 ->
    g x2 = g (g x2) ->
    In (g (g x2)) (f s2)
>>
*)

  (** * Facts and Tactics for Propositional Logic
      These lemmas and tactics are in a module so that they do
      not affect the namespace if you import the enclosing
      module [Decide]. *)
  Module FSetLogicalFacts.
    Require Export Decidable.
    Require Export Setoid.

    (** ** Lemmas and Tactics About Decidable Propositions
        XXX: The lemma [dec_iff] should have been included in
        [Decidable.v].  Some form of the [solve_decidable]
        tactics below would also make sense in [Decidable.v].
        *)

    Lemma dec_iff : forall P Q : Prop,
      decidable P ->
      decidable Q ->
      decidable (P <-> Q).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    (** With this hint database, we can leverage [auto] to check
        decidability of propositions. *)
    Hint Resolve
      dec_True dec_False dec_or dec_and dec_imp dec_not dec_iff
    : decidable_prop.

    (** [solve_decidable using lib] will solve goals about the
        decidability of a proposition, assisted by an auxiliary
        database of lemmas.  The database is intended to contain
        lemmas stating the decidability of base propositions,
        (e.g., the decidability of equality on a particular
        inductive type). *)
    Tactic Notation "solve_decidable" "using" ident(db) :=
      match goal with
      | |- decidable ?P =>
        solve [ auto 100 with decidable_prop db ]
      end.

    Tactic Notation "solve_decidable" :=
      solve_decidable using core.

    (** ** Propositional Equivalences Involving Negation
        These are all written with the unfolded form of
        negation, since I am not sure if setoid rewriting will
        always perform conversion. *)

    (** *** Eliminating Negations
        We begin with lemmas that, when read from left to right,
        can be understood as ways to eliminate uses of [not]. *)

    Lemma not_true_iff :
      (True -> False) <-> False.
    Proof.
      tauto.
    Qed.

    Lemma not_false_iff :
      (False -> False) <-> True.
    Proof.
      tauto.
    Qed.

    Lemma not_not_iff : forall P : Prop,
      decidable P ->
      (((P -> False) -> False) <-> P).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma contrapositive : forall P Q : Prop,
      decidable P ->
      (((P -> False) -> (Q -> False)) <-> (Q -> P)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma or_not_l_iff_1 : forall P Q : Prop,
      decidable P ->
      ((P -> False) \/ Q <-> (P -> Q)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma or_not_l_iff_2 : forall P Q : Prop,
      decidable Q ->
      ((P -> False) \/ Q <-> (P -> Q)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma or_not_r_iff_1 : forall P Q : Prop,
      decidable P ->
      (P \/ (Q -> False) <-> (Q -> P)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma or_not_r_iff_2 : forall P Q : Prop,
      decidable Q ->
      (P \/ (Q -> False) <-> (Q -> P)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma imp_not_l : forall P Q : Prop,
      decidable P ->
      (((P -> False) -> Q) <-> (P \/ Q)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    (** *** Moving Negations Around
        We have four lemmas that, when read from left to right,
        describe how to push negations toward the leaves of a
        proposition and, when read from right to left, describe
        how to pull negations toward the top of a proposition. *)

    Lemma not_or_iff : forall P Q : Prop,
      (P \/ Q -> False) <-> (P -> False) /\ (Q -> False).
    Proof.
      tauto.
    Qed.

    Lemma not_and_iff : forall P Q : Prop,
      (P /\ Q -> False) <-> (P -> Q -> False).
    Proof.
      tauto.
    Qed.

    Lemma not_imp_iff : forall P Q : Prop,
      decidable P ->
      (((P -> Q) -> False) <-> P /\ (Q -> False)).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    Lemma not_imp_rev_iff : forall P Q : Prop,
      decidable P ->
      (((P -> Q) -> False) <-> (Q -> False) /\ P).
    Proof.
      unfold decidable in *. tauto.
    Qed.

    (** ** Tactics for Negations *)

    Tactic Notation "fold" "any" "not" :=
      repeat (
        match goal with
        | H: context [?P -> False] |- _ =>
          fold (~ P) in H
        | |- context [?P -> False] =>
          fold (~ P)
        end).

    (** [push not using db] will pushes all negations to the
        leaves of propositions in the goal, using the lemmas in
        [db] to assist in checking the decidability of the
        propositions involved.  If [using db] is omitted, then
        [core] will be used.  Additional versions are provided
        to manipulate the hypotheses or the hypotheses and goal
        together.

        XXX: This tactic and the similar subsequent ones should
        have been defined using [autorewrite].  However, there
        is a bug in the order that Coq generates subgoals when
        rewriting using a setoid.  In order to work around this
        bug, these tactics had to be written out in an explicit
        way.  When the bug is fixed these tactics will break!!
        *)

    Tactic Notation "push" "not" "using" ident(db) :=
      unfold not, iff;
      repeat (
        match goal with
        (** simplification by not_true_iff *)
        | |- context [True -> False] =>
          rewrite not_true_iff
        (** simplification by not_false_iff *)
        | |- context [False -> False] =>
          rewrite not_false_iff
        (** simplification by not_not_iff *)
        | |- context [(?P -> False) -> False] =>
          rewrite (not_not_iff P);
            [ solve_decidable using db | ]
        (** simplification by contrapositive *)
        | |- context [(?P -> False) -> (?Q -> False)] =>
          rewrite (contrapositive P Q);
            [ solve_decidable using db | ]
        (** simplification by or_not_l_iff_1/_2 *)
        | |- context [(?P -> False) \/ ?Q] =>
          (rewrite (or_not_l_iff_1 P Q);
            [ solve_decidable using db | ]) ||
          (rewrite (or_not_l_iff_2 P Q);
            [ solve_decidable using db | ])
        (** simplification by or_not_r_iff_1/_2 *)
        | |- context [?P \/ (?Q -> False)] =>
          (rewrite (or_not_r_iff_1 P Q);
            [ solve_decidable using db | ]) ||
          (rewrite (or_not_r_iff_2 P Q);
            [ solve_decidable using db | ])
        (** simplification by imp_not_l *)
        | |- context [(?P -> False) -> ?Q] =>
          rewrite (imp_not_l P Q);
            [ solve_decidable using db | ]
        (** rewriting by not_or_iff *)
        | |- context [?P \/ ?Q -> False] =>
          rewrite (not_or_iff P Q)
        (** rewriting by not_and_iff *)
        | |- context [?P /\ ?Q -> False] =>
          rewrite (not_and_iff P Q)
        (** rewriting by not_imp_iff *)
        | |- context [(?P -> ?Q) -> False] =>
          rewrite (not_imp_iff P Q);
            [ solve_decidable using db | ]
        end);
      fold any not.

    Tactic Notation "push" "not" :=
      push not using core.

    Tactic Notation
      "push" "not" "in" "*" "|-" "using" ident(db) :=
      unfold not, iff in * |-;
      repeat (
        match goal with
        (** simplification by not_true_iff *)
        | H: context [True -> False] |- _ =>
          rewrite not_true_iff in H
        (** simplification by not_false_iff *)
        | H: context [False -> False] |- _ =>
          rewrite not_false_iff in H
        (** simplification by not_not_iff *)
        | H: context [(?P -> False) -> False] |- _ =>
          rewrite (not_not_iff P) in H;
            [ | solve_decidable using db ]
        (** simplification by contrapositive *)
        | H: context [(?P -> False) -> (?Q -> False)] |- _ =>
          rewrite (contrapositive P Q) in H;
            [ | solve_decidable using db ]
        (** simplification by or_not_l_iff_1/_2 *)
        | H: context [(?P -> False) \/ ?Q] |- _ =>
          (rewrite (or_not_l_iff_1 P Q) in H;
            [ | solve_decidable using db ]) ||
          (rewrite (or_not_l_iff_2 P Q) in H;
            [ | solve_decidable using db ])
        (** simplification by or_not_r_iff_1/_2 *)
        | H: context [?P \/ (?Q -> False)] |- _ =>
          (rewrite (or_not_r_iff_1 P Q) in H;
            [ | solve_decidable using db ]) ||
          (rewrite (or_not_r_iff_2 P Q) in H;
            [ | solve_decidable using db ])
        (** simplification by imp_not_l *)
        | H: context [(?P -> False) -> ?Q] |- _ =>
          rewrite (imp_not_l P Q) in H;
            [ | solve_decidable using db ]
        (** rewriting by not_or_iff *)
        | H: context [?P \/ ?Q -> False] |- _ =>
          rewrite (not_or_iff P Q) in H
        (** rewriting by not_and_iff *)
        | H: context [?P /\ ?Q -> False] |- _ =>
          rewrite (not_and_iff P Q) in H
        (** rewriting by not_imp_iff *)
        | H: context [(?P -> ?Q) -> False] |- _ =>
          rewrite (not_imp_iff P Q) in H;
            [ | solve_decidable using db ]
        end);
      fold any not.

    Tactic Notation "push" "not" "in" "*" "|-"  :=
      push not in * |- using core.

    Tactic Notation "push" "not" "in" "*" "using" ident(db) :=
      push not using db; push not in * |- using db.
    Tactic Notation "push" "not" "in" "*" :=
      push not in * using core.

    (** A simple test case to see how this works.  *)
    Lemma test_push : forall P Q R : Prop,
      decidable P ->
      decidable Q ->
      (~ True) ->
      (~ False) ->
      (~ ~ P) ->
      (~ (P /\ Q) -> ~ R) ->
      ((P /\ Q) \/ ~ R) ->
      (~ (P /\ Q) \/ R) ->
      (R \/ ~ (P /\ Q)) ->
      (~ R \/ (P /\ Q)) ->
      (~ P -> R) ->
      (~ ((R -> P) \/ (R -> Q))) ->
      (~ (P /\ R)) ->
      (~ (P -> R)) ->
      True.
    Proof.
      intros. push not in *. tauto.
    Qed.

    (** [pull not using db] will pull as many negations as
        possible toward the top of the propositions in the goal,
        using the lemmas in [db] to assist in checking the
        decidability of the propositions involved.  If [using
        db] is omitted, then [core] will be used.  Additional
        versions are provided to manipulate the hypotheses or
        the hypotheses and goal together. *)

    Tactic Notation "pull" "not" "using" ident(db) :=
      unfold not, iff;
      repeat (
        match goal with
        (** simplification by not_true_iff *)
        | |- context [True -> False] =>
          rewrite not_true_iff
        (** simplification by not_false_iff *)
        | |- context [False -> False] =>
          rewrite not_false_iff
        (** simplification by not_not_iff *)
        | |- context [(?P -> False) -> False] =>
          rewrite (not_not_iff P);
            [ solve_decidable using db | ]
        (** simplification by contrapositive *)
        | |- context [(?P -> False) -> (?Q -> False)] =>
          rewrite (contrapositive P Q);
            [ solve_decidable using db | ]
        (** simplification by or_not_l_iff_1/_2 *)
        | |- context [(?P -> False) \/ ?Q] =>
          (rewrite (or_not_l_iff_1 P Q);
            [ solve_decidable using db | ]) ||
          (rewrite (or_not_l_iff_2 P Q);
            [ solve_decidable using db | ])
        (** simplification by or_not_r_iff_1/_2 *)
        | |- context [?P \/ (?Q -> False)] =>
          (rewrite (or_not_r_iff_1 P Q);
            [ solve_decidable using db | ]) ||
          (rewrite (or_not_r_iff_2 P Q);
            [ solve_decidable using db | ])
        (** simplification by imp_not_l *)
        | |- context [(?P -> False) -> ?Q] =>
          rewrite (imp_not_l P Q);
            [ solve_decidable using db | ]
        (** rewriting by not_or_iff *)
        | |- context [(?P -> False) /\ (?Q -> False)] =>
          rewrite <- (not_or_iff P Q)
        (** rewriting by not_and_iff *)
        | |- context [?P -> ?Q -> False] =>
          rewrite <- (not_and_iff P Q)
        (** rewriting by not_imp_iff *)
        | |- context [?P /\ (?Q -> False)] =>
          rewrite <- (not_imp_iff P Q);
            [ solve_decidable using db | ]
        (** rewriting by not_imp_rev_iff *)
        | |- context [(?Q -> False) /\ ?P] =>
          rewrite <- (not_imp_rev_iff P Q);
            [ solve_decidable using db | ]
        end);
      fold any not.

    Tactic Notation "pull" "not" :=
      pull not using core.

    Tactic Notation
      "pull" "not" "in" "*" "|-" "using" ident(db) :=
      unfold not, iff in * |-;
      repeat (
        match goal with
        (** simplification by not_true_iff *)
        | H: context [True -> False] |- _ =>
          rewrite not_true_iff in H
        (** simplification by not_false_iff *)
        | H: context [False -> False] |- _ =>
          rewrite not_false_iff in H
        (** simplification by not_not_iff *)
        | H: context [(?P -> False) -> False] |- _ =>
          rewrite (not_not_iff P) in H;
            [ | solve_decidable using db ]
        (** simplification by contrapositive *)
        | H: context [(?P -> False) -> (?Q -> False)] |- _ =>
          rewrite (contrapositive P Q) in H;
            [ | solve_decidable using db ]
        (** simplification by or_not_l_iff_1/_2 *)
        | H: context [(?P -> False) \/ ?Q] |- _ =>
          (rewrite (or_not_l_iff_1 P Q) in H;
            [ | solve_decidable using db ]) ||
          (rewrite (or_not_l_iff_2 P Q) in H;
            [ | solve_decidable using db ])
        (** simplification by or_not_r_iff_1/_2 *)
        | H: context [?P \/ (?Q -> False)] |- _ =>
          (rewrite (or_not_r_iff_1 P Q) in H;
            [ | solve_decidable using db ]) ||
          (rewrite (or_not_r_iff_2 P Q) in H;
            [ | solve_decidable using db ])
        (** simplification by imp_not_l *)
        | H: context [(?P -> False) -> ?Q] |- _ =>
          rewrite (imp_not_l P Q) in H;
            [ | solve_decidable using db ]
        (** rewriting by not_or_iff *)
        | H: context [(?P -> False) /\ (?Q -> False)] |- _ =>
          rewrite <- (not_or_iff P Q) in H
        (** rewriting by not_and_iff *)
        | H: context [?P -> ?Q -> False] |- _ =>
          rewrite <- (not_and_iff P Q) in H
        (** rewriting by not_imp_iff *)
        | H: context [?P /\ (?Q -> False)] |- _ =>
          rewrite <- (not_imp_iff P Q) in H;
            [ | solve_decidable using db ]
        (** rewriting by not_imp_rev_iff *)
        | H: context [(?Q -> False) /\ ?P] |- _ =>
          rewrite <- (not_imp_rev_iff P Q) in H;
            [ | solve_decidable using db ]
        end);
      fold any not.

    Tactic Notation "pull" "not" "in" "*" "|-"  :=
      pull not in * |- using core.

    Tactic Notation "pull" "not" "in" "*" "using" ident(db) :=
      pull not using db; pull not in * |- using db.
    Tactic Notation "pull" "not" "in" "*" :=
      pull not in * using core.

    (** A simple test case to see how this works.  *)
    Lemma test_pull : forall P Q R : Prop,
      decidable P ->
      decidable Q ->
      (~ True) ->
      (~ False) ->
      (~ ~ P) ->
      (~ (P /\ Q) -> ~ R) ->
      ((P /\ Q) \/ ~ R) ->
      (~ (P /\ Q) \/ R) ->
      (R \/ ~ (P /\ Q)) ->
      (~ R \/ (P /\ Q)) ->
      (~ P -> R) ->
      (~ (R -> P) /\ ~ (R -> Q)) ->
      (~ P \/ ~ R) ->
      (P /\ ~ R) ->
      (~ R /\ P) ->
      True.
    Proof.
      intros. pull not in *. tauto.
    Qed.

  End FSetLogicalFacts.
  Import FSetLogicalFacts.

  (** * Auxiliary Tactics
      Again, these lemmas and tactics are in a module so that
      they do not affect the namespace if you import the
      enclosing module [Decide].  *)
  Module FSetDecideAuxiliary.

    (** ** Generic Tactics
        We begin by defining a few generic, useful tactics. *)

    (** [if t then t1 else t2] executes [t] and, if it does not
        fail, then [t1] will be applied to all subgoals
        produced.  If [t] fails, then [t2] is executed. *)
    Tactic Notation
      "if" tactic(t)
      "then" tactic(t1)
      "else" tactic(t2) :=
      first [ t; first [ t1 | fail 2 ] | t2 ].

    (** [prop P holds by t] succeeds (but does not modify the
        goal or context) if the proposition [P] can be proved by
        [t] in the current context.  Otherwise, the tactic
        fails. *)
    Tactic Notation "prop" constr(P) "holds" "by" tactic(t) :=
      let H := fresh in
      assert P as H by t;
      clear H.

    (** This tactic acts just like [assert ... by ...] but will
        fail if the context already contains the proposition. *)
    Tactic Notation "assert" "new" constr(e) "by" tactic(t) :=
      match goal with
      | H: e |- _ => fail 1
      | _ => assert e by t
      end.

    (** [subst++] is similar to [subst] except that
        - it never fails (as [subst] does on recursive
          equations),
        - it substitutes locally defined variable for their
          definitions,
        - it performs beta reductions everywhere, which may
          arise after substituting a locally defined function
          for its definition.
        *)
    Tactic Notation "subst" "++" :=
      repeat (
        match goal with
        | x : _ |- _ => subst x
        end);
      cbv zeta beta in *.

    (** If you have a negated goal and [H] is a negated
        hypothesis, then [contra H] exchanges your goal and [H],
        removing the negations.  (Just like [swap] but reuses
        the same name. *)
    Ltac contra H :=
      let J := fresh in
      unfold not;
      unfold not in H;
      intros J;
      apply H;
      clear H;
      rename J into H.

    (** [decompose records] calls [decompose record H] on every
        relevant hypothesis [H]. *)
    Tactic Notation "decompose" "records" :=
      repeat (
        match goal with
        | H: _ |- _ => progress (decompose record H); clear H
        end).

    (** ** Discarding Irrelevant Hypotheses
        We will want to clear the context of any
        non-FSet-related hypotheses in order to increase the
        speed of the tactic.  To do this, we will need to be
        able to decide which are relevant.  We do this by making
        a simple inductive definition classifying the
        propositions of interest. *)

    Inductive FSet_elt_Prop : Prop -> Prop :=
    | eq_Prop : forall (S : Set) (x y : S),
        FSet_elt_Prop (x = y)
    | eq_elt_prop : forall x y,
        FSet_elt_Prop (E.eq x y)
    | In_elt_prop : forall x s,
        FSet_elt_Prop (In x s)
    | True_elt_prop :
        FSet_elt_Prop True
    | False_elt_prop :
        FSet_elt_Prop False
    | conj_elt_prop : forall P Q,
        FSet_elt_Prop P ->
        FSet_elt_Prop Q ->
        FSet_elt_Prop (P /\ Q)
    | disj_elt_prop : forall P Q,
        FSet_elt_Prop P ->
        FSet_elt_Prop Q ->
        FSet_elt_Prop (P \/ Q)
    | impl_elt_prop : forall P Q,
        FSet_elt_Prop P ->
        FSet_elt_Prop Q ->
        FSet_elt_Prop (P -> Q)
    | not_elt_prop : forall P,
        FSet_elt_Prop P ->
        FSet_elt_Prop (~ P).

    Inductive FSet_Prop : Prop -> Prop :=
    | elt_FSet_Prop : forall P,
        FSet_elt_Prop P ->
        FSet_Prop P
    | Empty_FSet_Prop : forall s,
        FSet_Prop (Empty s)
    | Subset_FSet_Prop : forall s1 s2,
        FSet_Prop (Subset s1 s2)
    | Equal_FSet_Prop : forall s1 s2,
        FSet_Prop (Equal s1 s2).

    (** Here is the tactic that will throw away hypotheses that
        are not useful (for the intended scope of the [fsetdec]
        tactic). *)
    Hint Constructors FSet_elt_Prop FSet_Prop : FSet_Prop.
    Ltac discard_nonFSet :=
      decompose records;
      repeat (
        match goal with
        | H : ?P |- _ =>
          if prop (FSet_Prop P) holds by
            (auto 100 with FSet_Prop)
          then fail
          else clear H
        end).

    (** ** Turning Set Operators into Propositional Connectives
        The lemmas from [FSetFacts] will be used to break down
        set operations into propositional formulas built over
        the predicates [In] and [E.eq] applied only to
        variables.  We are going to use them with [autorewrite].
        *)
    Module F := FSetFacts.Facts M.
    Hint Rewrite
      F.empty_iff F.singleton_iff F.add_iff F.remove_iff
      F.union_iff F.inter_iff F.diff_iff
    : set_simpl.

    (** ** Decidability of FSet Propositions *)

    (** [In] is decidable. *)
    Module D := DepOfNodep M.
    Lemma dec_In : forall x s,
      decidable (In x s).
    Proof.
      intros x s. red. destruct (D.mem x s); auto.
    Qed.

    (** [E.eq] is decidable. *)
    Lemma dec_eq : forall (x y : E.t),
      decidable (E.eq x y).
    Proof.
      intros x y. red. destruct (E.compare x y); auto.
    Qed.

    (** The hint database [FSet_decidability] will be given to
        the [push_neg] tactic from the module [Negation]. *)
    Hint Resolve dec_In dec_eq : FSet_decidability.

    (** ** Normalizing Propositions About Equality
        We have to deal with the fact that [E.eq] may be
        convertible with Coq's equality.  Thus, we will find the
        following tactics useful to replace one form with the
        other everywhere. *)

    (** The next tactic, [Logic_eq_to_E_eq], mentions the term
        [E.t]; thus, we must ensure that [E.t] is used in favor
        of any other convertible but syntactically distinct
        term. *)
    Ltac change_to_E_t :=
      repeat (
        match goal with
        | H : ?T |- _ =>
          progress (change T with E.t in H);
          repeat (
            match goal with
            | J : _ |- _ => progress (change T with E.t in J)
            | |- _ => progress (change T with E.t)
            end )
        end).

    (** These two tactics take us from Coq's built-in equality
        to [E.eq] (and vice versa) when possible. *)

    Ltac Logic_eq_to_E_eq :=
      repeat (
        match goal with
        | H: _ |- _ =>
          progress (change (@Logic.eq E.t) with E.eq in H)
        | |- _ =>
          progress (change (@Logic.eq E.t) with E.eq)
        end).

    Ltac E_eq_to_Logic_eq :=
      repeat (
        match goal with
        | H: _ |- _ =>
          progress (change E.eq with (@Logic.eq E.t) in H)
        | |- _ =>
          progress (change E.eq with (@Logic.eq E.t))
        end).

    (** This tactic works like the built-in tactic [subst], but
        at the level of set element equality (which may not be
        the convertible with Coq's equality). *)
    Ltac substFSet :=
      repeat (
        match goal with
        | H: E.eq ?x ?y |- _ => rewrite H in *; clear H
        end).

    (** ** Considering Decidability of Base Propositions
        This tactic adds assertions about the decidability of
        [E.eq] and [In] to the context.  This is necessary for
        the completeness of the [fsetdec] tactic.  However, in
        order to minimize the cost of proof search, we should be
        careful to not add more than we need.  Once negations
        have been pushed to the leaves of the propositions, we
        only need to worry about decidability for those base
        propositions that appear in a negated form. *)
    Ltac assert_decidability :=
      (** We actually don't want these rules to fire if the
          syntactic context in the patterns below is trivially
          empty, but we'll just do some clean-up at the
          afterward.  *)
      repeat (
        match goal with
        | H: context [~ E.eq ?x ?y] |- _ =>
          assert new (E.eq x y \/ ~ E.eq x y) by (apply dec_eq)
        | H: context [~ In ?x ?s] |- _ =>
          assert new (In x s \/ ~ In x s) by (apply dec_In)
        | |- context [~ E.eq ?x ?y] =>
          assert new (E.eq x y \/ ~ E.eq x y) by (apply dec_eq)
        | |- context [~ In ?x ?s] =>
          assert new (In x s \/ ~ In x s) by (apply dec_In)
        end);
      (** Now we eliminate the useless facts we added (because
          they would likely be very harmful to performance). *)
      repeat (
        match goal with
        | _: ~ ?P, H : ?P \/ ~ ?P |- _ => clear H
        end).

    (** ** Handling [Empty], [Subset], and [Equal]
        This tactic instantiates universally quantified
        hypotheses (which arise from the unfolding of [Empty],
        [Subset], and [Equal]) for each of the set element
        expressions that is involved in some membership or
        equality fact.  Then it throws away those hypotheses,
        which should no longer be needed. *)
    Ltac inst_FSet_hypotheses :=
      repeat (
        match goal with
        | H : forall a : E.t, _,
          _ : context [ In ?x _ ] |- _ =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        | H : forall a : E.t, _
          |- context [ In ?x _ ] =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        | H : forall a : E.t, _,
          _ : context [ E.eq ?x _ ] |- _ =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        | H : forall a : E.t, _
          |- context [ E.eq ?x _ ] =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        | H : forall a : E.t, _,
          _ : context [ E.eq _ ?x ] |- _ =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        | H : forall a : E.t, _
          |- context [ E.eq _ ?x ] =>
          let P := type of (H x) in
          assert new P by (exact (H x))
        end);
      repeat (
        match goal with
        | H : forall a : E.t, _ |- _ =>
          clear H
        end).

    (** ** The Core [fsetdec] Auxiliary Tactics *)

    (** Here is the crux of the proof search.  Recursion through
        [intuition]!  (This will terminate if I correctly
        understand the behavior of [intuition].) *)
    Ltac fsetdec_rec :=
      try (match goal with
      | H: E.eq ?x ?x -> False |- _ => destruct H
      end);
      (reflexivity ||
      contradiction ||
      (progress substFSet; intuition fsetdec_rec)).

    (** If we add [unfold Empty, Subset, Equal in *; intros;] to
        the beginning of this tactic, it will satisfy the same
        specification as the [fsetdec] tactic; however, it will
        be much slower than necessary without the pre-processing
        done by the wrapper tactic [fsetdec]. *)
    Ltac fsetdec_body :=
      inst_FSet_hypotheses;
      autorewrite with set_simpl in *;
      push not in * using FSet_decidability;
      substFSet;
      assert_decidability;
      auto using E.eq_refl;
      (intuition fsetdec_rec) ||
      fail 1
        "because the goal is beyond the scope of this tactic".

  End FSetDecideAuxiliary.
  Import FSetDecideAuxiliary.

  (** * The [fsetdec] Tactic
      Here is the top-level tactic (the only one intended for
      clients of this library).  It's specification is given at
      the top of the file. *)
  Ltac fsetdec :=
    (** We first unfold any occurrences of [iff]. *)
    unfold iff in *;
    (** We fold occurrences of [not] because it is better for
        [intros] to leave us with a goal of [~ P] than a goal of
        [False]. *)
    fold any not; intros;
    (** Now we decompose conjunctions, which will allow the
        [discard_nonFSet] and [assert_decidability] tactics to
        do a much better job. *)
    decompose records;
    discard_nonFSet;
    (** We unfold these defined propositions on finite sets.  If
        our goal was one of them, then have one more item to
        introduce now. *)
    unfold Empty, Subset, Equal in *; intros;
    (** We now want to get rid of all uses of [=] in favor of
        [E.eq].  However, the best way to eliminate a [=] in
        the context is with [subst], so we will try that first.
        In fact, we may as well convert uses of [E.eq] into [=]
        where possible before we do [subst] so that we can get
        even more mileage out of it.  Then we will convert all
        remaining uses of [=] back to [E.eq] when possible.  We
        use [change_to_E_t] to ensure that we have a canonical
        name for set elements, so that [Logic_eq_to_E_eq] will
        work properly. *)
    change_to_E_t; E_eq_to_Logic_eq; subst++; Logic_eq_to_E_eq;
    (** The next optimization is to swap a negated goal with a
        negated hypothesis when possible.  Any swap will improve
        performance by eliminating the total number of
        negations, but we will get the maximum benefit if we
        swap the goal with a hypotheses mentioning the same set
        element, so we try that first.  If we reach the fourth
        branch below, we attempt any swap.  However, to maintain
        completeness of this tactic, we can only perform such a
        swap with a decidable proposition; hence, we first test
        whether the hypothesis is an [FSet_elt_Prop], noting
        that any [FSet_elt_Prop] is decidable. *)
    pull not using FSet_decidability;
    unfold not in *;
    match goal with
    | H: (In ?x ?r) -> False |- (In ?x ?s) -> False =>
      contra H; fsetdec_body
    | H: (In ?x ?r) -> False |- (E.eq ?x ?y) -> False =>
      contra H; fsetdec_body
    | H: (In ?x ?r) -> False |- (E.eq ?y ?x) -> False =>
      contra H; fsetdec_body
    | H: ?P -> False |- ?Q -> False =>
      if prop (FSet_elt_Prop P) holds by
        (auto 100 with FSet_Prop)
      then (contra H; fsetdec_body)
      else fsetdec_body
    | |- _ =>
      fsetdec_body
    end.

  (** * Examples *)

  Module FSetDecideTestCases.

    Lemma test_eq_trans_1 : forall x y z s,
      E.eq x y ->
      ~ ~ E.eq z y ->
      In x s ->
      In z s.
    Proof. fsetdec. Qed.

    Lemma test_eq_trans_2 : forall x y z r s,
      In x (singleton y) ->
      ~ In z r ->
      ~ ~ In z (add y r) ->
      In x s ->
      In z s.
    Proof. fsetdec. Qed.

    Lemma test_eq_neq_trans_1 : forall w x y z s,
      E.eq x w ->
      ~ ~ E.eq x y ->
      ~ E.eq y z ->
      In w s ->
      In w (remove z s).
    Proof. fsetdec. Qed.

    Lemma test_eq_neq_trans_2 : forall w x y z r1 r2 s,
      In x (singleton w) ->
      ~ In x r1 ->
      In x (add y r1) ->
      In y r2 ->
      In y (remove z r2) ->
      In w s ->
      In w (remove z s).
    Proof. fsetdec. Qed.

    Lemma test_In_singleton : forall x,
      In x (singleton x).
    Proof. fsetdec. Qed.

    Lemma test_Subset_add_remove : forall x s,
      s [<=] (add x (remove x s)).
    Proof. fsetdec. Qed.

    Lemma test_eq_disjunction : forall w x y z,
      In w (add x (add y (singleton z))) ->
      E.eq w x \/ E.eq w y \/ E.eq w z.
    Proof. fsetdec. Qed.

    Lemma test_not_In_disj : forall x y s1 s2 s3 s4,
      ~ In x (union s1 (union s2 (union s3 (add y s4)))) ->
      ~ (In x s1 \/ In x s4 \/ E.eq y x).
    Proof. fsetdec. Qed.

    Lemma test_not_In_conj : forall x y s1 s2 s3 s4,
      ~ In x (union s1 (union s2 (union s3 (add y s4)))) ->
      ~ In x s1 /\ ~ In x s4 /\ ~ E.eq y x.
    Proof. fsetdec. Qed.

    Lemma test_iff_conj : forall a x s s',
    (In a s' <-> E.eq x a \/ In a s) ->
    (In a s' <-> In a (add x s)).
    Proof. fsetdec. Qed.

    Lemma test_set_ops_1 : forall x q r s,
      (singleton x) [<=] s ->
      Empty (union q r) ->
      Empty (inter (diff s q) (diff s r)) ->
      ~ In x s.
    Proof. fsetdec. Qed.

    Lemma eq_chain_test : forall x1 x2 x3 x4 s1 s2 s3 s4,
      Empty s1 ->
      In x2 (add x1 s1) ->
      In x3 s2 ->
      ~ In x3 (remove x2 s2) ->
      ~ In x4 s3 ->
      In x4 (add x3 s3) ->
      In x1 s4 ->
      Subset (add x4 s4) s4.
    Proof. fsetdec. Qed.

    Lemma test_too_complex : forall x y z r s,
      E.eq x y ->
      (In x (singleton y) -> r [<=] s) ->
      In z r ->
      In z s.
    Proof.
      (** [fsetdec] is not intended to solve this directly. *)
      intros until s; intros Heq H Hr; lapply H; fsetdec.
    Qed.

    Lemma function_test_1 :
      forall (f : t -> t),
      forall (g : elt -> elt),
      forall (s1 s2 : t),
      forall (x1 x2 : elt),
      Equal s1 (f s2) ->
      E.eq x1 (g (g x2)) ->
      In x1 s1 ->
      In (g (g x2)) (f s2).
    Proof. fsetdec. Qed.

    Lemma function_test_2 :
      forall (f : t -> t),
      forall (g : elt -> elt),
      forall (s1 s2 : t),
      forall (x1 x2 : elt),
      Equal s1 (f s2) ->
      E.eq x1 (g x2) ->
      In x1 s1 ->
      g x2 = g (g x2) ->
      In (g (g x2)) (f s2).
    Proof.
      (** [fsetdec] is not intended to solve this directly. *)
      intros until 3. intros g_eq. rewrite <- g_eq. fsetdec.
    Qed.

  End FSetDecideTestCases.

End Decide.
