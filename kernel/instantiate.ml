
(* $Id$ *)

open Pp
open Util
open Names
open Term
open Sign
open Evd
open Declarations
open Environ

let is_id_inst inst =
  let is_id (id,c) = match kind_of_term c with
    | IsVar id' -> id = id'
    | _ -> false
  in
  List.for_all is_id inst

let instantiate_constr sign c args =
  let inst = instantiate_named_context  sign args in
  if is_id_inst inst then
    c
  else
    replace_vars inst c

let instantiate_type sign tty args =
  type_app (fun c -> instantiate_constr sign c args) tty

(* Constants. *)

(* constant_type gives the type of a constant *)
let constant_type env sigma (sp,args) =
  let cb = lookup_constant sp env in
  (* TODO: check args *)
  instantiate_type cb.const_hyps cb.const_type (Array.to_list args)

type const_evaluation_result = NoBody | Opaque

exception NotEvaluableConst of const_evaluation_result

let constant_value env (sp,args) =
  let cb = lookup_constant sp env in
  if cb.const_opaque then raise (NotEvaluableConst Opaque);
  match cb.const_body with
    | Some body -> 
        instantiate_constr cb.const_hyps body (Array.to_list args)
    | None ->
	raise (NotEvaluableConst NoBody)

let constant_opt_value env cst =
  try Some (constant_value env cst)
  with NotEvaluableConst _ -> None

(* Existentials. *)

let name_of_existential n = id_of_string ("?" ^ string_of_int n)

let existential_type sigma (n,args) =
  let info = Evd.map sigma n in
  let hyps = info.evar_hyps in
  (* TODO: check args [this comment was in Typeops] *)
  instantiate_constr hyps info.evar_concl (Array.to_list args)

exception NotInstantiatedEvar

let existential_value sigma (n,args) =
  let info = Evd.map sigma n in
  let hyps = info.evar_hyps in
  match evar_body info with
    | Evar_defined c ->
	instantiate_constr hyps c (Array.to_list args)
    | Evar_empty ->
	raise NotInstantiatedEvar

let existential_opt_value sigma ev =
  try Some (existential_value sigma ev)
  with NotInstantiatedEvar -> None
