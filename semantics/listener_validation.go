// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package semantics

import "ballerina-lang-go/semtypes"

// validateListenerType structurally checks whether ty is a valid listener
// object type and, on success, returns its projected service-target type T
// and attach-point type A.
//
// There is no single fixed SemType that all listeners are subtypes of: with
// function-parameter contravariance, using `service object {}` as T makes
// the would-be top a strict bottom of the parametric family (only listeners
// accepting every service satisfy it), and using NEVER admits objects whose
// `attach` first parameter is any type at all (e.g. `int`), losing the
// service-object bound. We therefore validate by projecting T, A out of the
// candidate's own `attach` signature, bounding them against the spec
// constraints, and finally checking the candidate is a subtype of
// `ListenerTy(T, A)` to pin down the remaining four methods.
func validateListenerType(cx semtypes.Context, ty semtypes.SemType, attachPointBound semtypes.SemType) (semtypes.SemType, semtypes.SemType, bool) {
	attachFnTy := semtypes.ObjectMemberType(cx, semtypes.StringConst("attach"), ty)
	if attachFnTy == nil {
		return nil, nil, false
	}
	paramList := semtypes.FunctionParamListType(cx, attachFnTy)
	if paramList == nil {
		return nil, nil, false
	}
	t := semtypes.ListMemberTypeInnerVal(cx, paramList, semtypes.IntConst(0))
	a := semtypes.ListMemberTypeInnerVal(cx, paramList, semtypes.IntConst(1))
	if !semtypes.IsSubtype(cx, t, semtypes.CreateServiceObject(cx)) {
		return nil, nil, false
	}
	if !semtypes.IsSubtype(cx, a, attachPointBound) {
		return nil, nil, false
	}
	if !semtypes.IsSubtype(cx, ty, semtypes.ListenerTy(cx, t, a)) {
		return nil, nil, false
	}
	return t, a, true
}

// listenerAttachPointBound is the spec-mandated upper bound on a listener's
// attach-point parameter type: `string[] | string | ()`.
func listenerAttachPointBound(cx semtypes.Context) semtypes.SemType {
	listDefn := semtypes.NewListDefinition()
	stringArr := listDefn.DefineListTypeWrapped(cx.Env(), nil, 0, semtypes.STRING, semtypes.CellMutability_CELL_MUT_LIMITED)
	return semtypes.Union(stringArr, semtypes.Union(semtypes.STRING, semtypes.NIL))
}
