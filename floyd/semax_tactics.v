Require Import VST.floyd.base2.
Require Import VST.floyd.client_lemmas.
Require Import VST.floyd.forward_lemmas.

(* Bug: abbreviate replaces _ALL_ instances, when sometimes
  we only want just one. *)
Tactic Notation "abbreviate" constr(y) "as"  ident(x)  :=
   (first [ is_var y
           |  let x' := fresh x in pose (x':= @abbreviate _ y);
               change y with x']).

Tactic Notation "abbreviate" constr(y) ":" constr(t) "as"  ident(x)  :=
   (first [ is_var y
           |  let x' := fresh x in pose (x':= @abbreviate t y);
               change y with x']).

Ltac unfold_abbrev :=
  repeat match goal with H := @abbreviate _ _ |- _ =>
                        unfold H, abbreviate; clear H
            end.

Ltac unfold_abbrev' :=
  repeat match goal with
             | H := @abbreviate ret_assert _ |- _ =>
                        unfold H, abbreviate; clear H
(*             | H := @abbreviate tycontext _ |- _ =>
                        unfold H, abbreviate; clear H
*)
             | H := @abbreviate statement _ |- _ =>
                        unfold H, abbreviate; clear H
            end.

Ltac unfold_abbrev_ret :=
  repeat match goal with H := @abbreviate ret_assert _ |- _ =>
                        unfold H, abbreviate; clear H
            end.

Ltac unfold_abbrev_commands :=
  repeat match goal with H := @abbreviate statement _ |- _ =>
                        unfold H, abbreviate; clear H
            end.

Ltac clear_abbrevs :=  repeat match goal with
                                    | H := @abbreviate statement _ |- _ => clear H
                                    | H := @abbreviate ret_assert _ |- _ => clear H
                                    | H := @abbreviate tycontext _ |- _ => clear H
                                    end.

Arguments var_types !Delta / .

Ltac reduce_snd S1 :=
match goal with
| |- context [snd ?A] =>
   let j := fresh in set (j := snd A) at 1;
   hnf in j;
   reduce_snd S1;
   subst j
| |- _ => intro S1; simpl in S1
end.

Ltac ensure_no_augment_funspecs Gprog :=
            let x := fresh "x" in
            pose (x := Gprog); unfold Gprog in x;
             match goal with
             | x:=augment_funspecs _ _:_
               |- _ =>
                   fail 10 "Do not define Gprog with augment_funspecs,"
                    "use with_library instead; see the reference manual"
             | |- _ => clear x
             end.

Ltac check_ground_ptree t :=
match t with
| @PTree.Node _ ?a _ ?b => check_ground_ptree a; check_ground_ptree b
| @PTree.Leaf _ => idtac
end.

Ltac check_ground_Delta :=
match goal with
|  Delta := @abbreviate _ (mk_tycontext ?A ?B _ ?D _) |- _ =>
   first [check_ground_ptree A | fail 99 "Temps component of Delta not a ground PTree"];
   first [check_ground_ptree B | fail 99 "Local Vars component of Delta not a ground PTree"];
   first [check_ground_ptree D | fail 99 "Globals component of Delta not a ground PTree"]
end;
match goal with
|  Delta := @abbreviate _ (mk_tycontext ?A ?B _ ?D ?DS),
   DS' := @abbreviate (PTree.t funspec) ?E  |- _ =>
   constr_eq DS DS';
   first [check_ground_ptree E | fail 99 "Delta_specs not a ground PTree"]
|  Delta := @abbreviate _ (mk_tycontext ?A ?B _ ?D ?DS),
   DS' : (PTree.t funspec) |- _ =>
   constr_eq DS DS'
end.

(* This tactic is carefully tuned to avoid proof blowups,
  both in execution and in Qed *)
Ltac simplify_func_tycontext' DD :=
  match DD with context [(func_tycontext ?f ?V ?G)] =>
   ensure_no_augment_funspecs G;
    let D1 := fresh "D1" in let Delta := fresh "Delta" in
    pose (Delta := @abbreviate tycontext (func_tycontext f V G));
    change (func_tycontext f V G) with Delta;
    unfold func_tycontext, make_tycontext in Delta;
    let DS := fresh "Delta_specs" in let DS1 := fresh "DS1" in 
    pose (DS1 := make_tycontext_s G);
    pose (DS := @abbreviate (PTree.t funspec) DS1);
    change (make_tycontext_s G) with DS in Delta;
    hnf in DS1;
    cbv beta iota delta [ptree_set] in DS1;
    subst DS1;
    cbv beta iota zeta delta - [abbreviate DS] in Delta;
    check_ground_Delta
   end.

Ltac simplify_func_tycontext :=
match goal with
 | |- semax ?DD _ _ _ => simplify_func_tycontext'  DD
 | |- ENTAIL ?DD, _ |-- _ => simplify_func_tycontext'  DD
end.

(*
Ltac simplify_Delta_at DS Delta D :=
 match D with
 | _ => unfold D
 | _ => simplify_func_tycontext D
 | mk_tycontext ?a ?b ?c ?d ?e =>
     let DS := fresh "Delta_specs" in set (DS := e : PTree.t funspec);
     change e with (@abbreviate (PTree.t funspec) e) in DS;
     let E := fresh "Delta" in set (E := mk_tycontext a b c d DS);
     change (mk_tycontext a b c d DS) with (@abbreviate _ (mk_tycontext a b c d DS)) in E
 | 
 end.
*)

Definition with_Delta_specs (DS: PTree.t funspec) (Delta: tycontext) : tycontext :=
  match Delta with
    mk_tycontext a b c d _ => mk_tycontext a b c d DS
  end.

Ltac compute_in_Delta :=
 lazymatch goal with
 | DS := @abbreviate (PTree.t funspec) _, Delta := @abbreviate tycontext _ |- _ =>
           cbv beta iota zeta delta - [abbreviate DS] in Delta
 | Delta := @abbreviate tycontext _ |- _ =>
           cbv beta iota zeta delta - [abbreviate] in Delta
 end.

(* This tactic is carefully tuned to avoid proof blowups,
  both in execution and in Qed *)
Ltac simplify_Delta :=
match goal with
 | Delta := @abbreviate tycontext _ |- _ => clear Delta; simplify_Delta
 | DS := @abbreviate (PTree.t funspec) _ |- _ => clear DS; simplify_Delta
 | D1 := @abbreviate tycontext _ |- semax ?D _ _ _ => 
       constr_eq D1 D (* ONLY this case terminates! *)
 | |- semax ?D _ _ _ => unfold D; simplify_Delta
 | |- _ => simplify_func_tycontext; simplify_Delta
 | |- semax (mk_tycontext ?a ?b ?c ?d ?e) _ _ _ => (* delete this case? *)
     let DS := fresh "Delta_specs" in set (DS := e : PTree.t funspec);
     change e with (@abbreviate (PTree.t funspec) e) in DS;
     let D := fresh "Delta" in set (D := mk_tycontext a b c d DS);
     change (mk_tycontext a b c d DS) with (@abbreviate _ (mk_tycontext a b c d DS)) in D
 | |- _ => fail "simplify_Delta did not put Delta_specs and Delta into canonical form"
 end.

(*
Ltac build_Struct_env :=
 match goal with
 | SE := @abbreviate type_id_env _ |- _ => idtac
 | Delta := @abbreviate tycontext _ |- _ =>
    pose (Struct_env := @abbreviate _ (type_id_env.compute_type_id_env Delta));
    simpl type_id_env.compute_type_id_env in Struct_env
 end.
*)

Ltac abbreviate_semax :=
 match goal with
 | |- semax _ _ _ _ =>
  simplify_Delta;
  match goal with
  | P := @abbreviate ret_assert _ |- semax _ _ _ ?Q => constr_eq P Q
  | |- _ => 
    repeat match goal with
    | P := @abbreviate ret_assert _ |- _ => subst P
    end;
    match goal with |- semax _ _ _ ?P => 
       abbreviate P : ret_assert as POSTCONDITION
    end
  end;
  repeat match goal with
  | MC := @abbreviate statement _ |- _ => unfold abbreviate in MC; subst MC
  end;
  match goal with |- semax _ _ ?C _ =>
            match C with
            | Ssequence ?C1 ?C2 =>
               (* use the next 3 lines instead of "abbreviate"
                  in case C1 contains an instance of C2 *)
                let MC := fresh "MORE_COMMANDS" in
                pose (MC := @abbreviate _ C2);
                change C with (Ssequence C1 MC);
                match C1 with
                | Swhile _ ?C3 => abbreviate C3 as LOOP_BODY
                | _ => idtac
                end
            | Swhile _ ?C3 => abbreviate C3 as LOOP_BODY
            | _ => idtac
            end
  end
 | |- _ |-- _ => unfold_abbrev_ret
 end;
 clear_abbrevs;
 simpl typeof.

Ltac check_Delta :=
match goal with
 | Delta := @abbreviate tycontext (mk_tycontext _ _ _ _ _) |- _ =>
    match goal with
    | |- _ => clear Delta; check_Delta
    | |- semax Delta _ _ _ => idtac
    end
 | _ => simplify_Delta;
     match goal with |- semax ?D _ _ _ =>
            abbreviate D : tycontext as Delta
     end
end.

Ltac normalize_postcondition :=  (* produces a normal_ret_assert *)
 match goal with
 | P := _ |- semax _ _ _ ?P =>
     unfold P, abbreviate; clear P; normalize_postcondition
 | |- semax _ _ _ (normal_ret_assert _) => idtac
 | |- _ => apply sequential
  end;
 autorewrite with ret_assert.

Ltac weak_normalize_postcondition := (* does not insist on normal_ret_assert *)
 repeat match goal with P := @abbreviate ret_assert _ |- _ =>
               unfold abbreviate in P; subst P end;
 autorewrite with ret_assert.

(**** BEGIN semax_subcommand stuff  *)

Ltac semax_subcommand V G F :=
  abbreviate_semax;
  match goal with |- semax ?Delta _ _ _ =>
      change Delta with (func_tycontext F V G);
      repeat
         match goal with
          | P := @abbreviate statement _ |- _ => unfold abbreviate in P; subst P
          | P := @abbreviate ret_assert _ |- _ => unfold abbreviate in P; subst P
         end;
       weak_normalize_postcondition
  end.

(**** END semax_subcommand stuff *)

Arguments PTree.fold {A} {B} f m v / .

Ltac no_reassociate_stmt S := S.

Ltac find_statement_in_body f reassoc pat :=
  let body := eval hnf in (fn_body f)
      in let body := constr:(Ssequence body (Sreturn None))
      in let body := reassoc body
      in let S := pat body
      in exact S.
