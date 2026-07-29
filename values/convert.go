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

package values

import (
	"fmt"

	"ballerina/decimal"
	"ballerina/semtypes"
)

// numericTypes lists the numeric basic types, for which tryConvertBasicType can actually
// widen or narrow a value (e.g. int -> float). candidateTypes tries an exact match among these
// before one that would need conversion.
var numericTypes = []semtypes.SemType{semtypes.INT, semtypes.FLOAT, semtypes.DECIMAL}

// nonStructuralTypes lists the scalar basic types outside MAPPING and LIST that are not
// numeric. tryConvertBasicType has no conversion for these: a value either already satisfies
// the candidate or the candidate can never succeed, so candidateTypes need not order them.
var nonStructuralTypes = []semtypes.SemType{
	semtypes.NIL, semtypes.BOOLEAN, semtypes.STRING, semtypes.XML, semtypes.ERROR,
}

// CloneWithType implements the cloneWithType abstract operation defined in the Ballerina spec
// (https://ballerina.io/spec/lang/master/#section_16.6).
//
// It constructs a value of targetType by deep-cloning value, applying the following conversions:
//   - the inherent type of any structural value comes from targetType
//   - numeric values may be converted between int, float, and decimal via NumericConvert
//   - missing required fields (with or without defaults) cause a ConversionError; default injection
//     is not yet implemented (tracked as a separate work item)
//
// Cyclic values return a ConversionError: per the cloneWithType contract, the graph structure
// is not preserved and the result is always a tree.
//
// On failure it returns a ConversionError wrapped as *Error.
func CloneWithType(tc semtypes.Context, value BalValue, targetType semtypes.SemType) (BalValue, *Error) {
	result, err := convert(tc, value, targetType, nil)
	if err != nil {
		return nil, wrapConversionError(err)
	}
	return result, nil
}

// convert converts value to target, trying each of target's basic-type constituents in turn;
// candidateTypes orders them so any constituent value already satisfies precedes one that would
// need numeric conversion, so a single pass suffices to prefer an exact match. See
// conversionFailureFor for how a total failure is reported.
func convert(tc semtypes.Context, value BalValue, target semtypes.SemType, visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
	candidates := candidateTypes(tc, SemTypeForValue(value), target)
	children := make([]*conversionFailure, 0, len(candidates))
	for _, candidate := range candidates {
		result, err := tryConvert(tc, value, candidate, visiting)
		if err == nil {
			return result, nil
		}
		children = append(children, err)
	}
	return nil, conversionFailureFor(tc, value, target, children)
}

// candidateTypes decomposes ty into its per-basic-type constituents (e.g. the mapping and list
// alternatives of a union), skipping any constituent that is empty under tc. Non-numeric scalar
// constituents are unordered, since they either already match or can never convert. Numeric
// constituents that valueTy already satisfies without conversion are ordered first, so a caller
// trying candidates in order finds an exact match before any that would widen or narrow the
// value numerically.
func candidateTypes(tc semtypes.Context, valueTy semtypes.SemType, ty semtypes.SemType) []semtypes.SemType {
	var members []semtypes.SemType
	basic := semtypes.WidenToBasicTypes(ty)

	if semtypes.ContainsBasicType(basic, semtypes.MAPPING) {
		mappingTy := semtypes.Intersect(ty, semtypes.MAPPING)
		for _, alt := range semtypes.MappingAlternatives(tc, mappingTy) {
			members = append(members, alt.SemType)
		}
	}
	if semtypes.ContainsBasicType(basic, semtypes.LIST) {
		listTy := semtypes.Intersect(ty, semtypes.LIST)
		for _, alt := range semtypes.ListAlternatives(tc, listTy) {
			members = append(members, alt.SemType)
		}
	}

	for _, bt := range nonStructuralTypes {
		if semtypes.ContainsBasicType(basic, bt) {
			member := semtypes.Intersect(ty, bt)
			if !semtypes.IsEmpty(tc, member) {
				members = append(members, member)
			}
		}
	}

	isNumericValue := semtypes.IsSubtype(tc, valueTy, semtypes.NUMBER)

	var exact, coerced []semtypes.SemType
	for _, bt := range numericTypes {
		if !semtypes.ContainsBasicType(basic, bt) {
			continue
		}
		member := semtypes.Intersect(ty, bt)
		if semtypes.IsEmpty(tc, member) {
			continue
		}
		if isNumericValue && semtypes.IsSubtype(tc, valueTy, member) {
			exact = append(exact, member)
		} else {
			coerced = append(coerced, member)
		}
	}
	members = append(members, exact...)
	members = append(members, coerced...)
	return members
}

// tryConvert converts value to a single, already-decomposed basic-type target (never a union),
// dispatching on value's shape. Cycle detection only applies to *Map/*List, since only
// structured values can participate in a cycle.
func tryConvert(tc semtypes.Context, value BalValue, target semtypes.SemType, visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
	var convertStructured func(map[BalValue]struct{}) (BalValue, *conversionFailure)
	switch v := value.(type) {
	case *Map:
		if !semtypes.IsSubtype(tc, target, semtypes.MAPPING) {
			return nil, incompatibleConversion(tc, value, target)
		}
		convertStructured = func(visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
			return tryConvertMap(tc, v, target, visiting)
		}
	case *List:
		if !semtypes.IsSubtype(tc, target, semtypes.LIST) {
			return nil, incompatibleConversion(tc, value, target)
		}
		convertStructured = func(visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
			return tryConvertList(tc, v, target, visiting)
		}
	default:
		return tryConvertBasicType(tc, v, target)
	}

	visiting, cycleErr := enterCycleCheck(tc, SemTypeForValue(value), value, visiting)
	if cycleErr != nil {
		return nil, cycleErr
	}
	defer delete(visiting, value)
	return convertStructured(visiting)
}

// enterCycleCheck lazily initialises visiting and checks whether source is already being
// converted in the current recursion stack. The caller must defer delete(visiting, source)
// on success so DAG-shared nodes are not falsely reported as cycles on the second reference.
func enterCycleCheck(tc semtypes.Context, sourceType semtypes.SemType, source BalValue, visiting map[BalValue]struct{}) (map[BalValue]struct{}, *conversionFailure) {
	if visiting == nil {
		visiting = make(map[BalValue]struct{})
	}
	if _, cycle := visiting[source]; cycle {
		return visiting, newConversionFailure(fmt.Sprintf("'%s' value has cyclic reference", semtypes.ToString(tc, sourceType)))
	}
	visiting[source] = struct{}{}
	return visiting, nil
}

func tryConvertMap(tc semtypes.Context, source *Map, target semtypes.SemType, visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
	atomic := semtypes.ToMappingAtomicType(tc, target)

	entries := make([]MapEntry, 0, source.Len())
	seen := make(map[string]struct{}, source.Len())

	for _, key := range source.Keys() {
		seen[key] = struct{}{}
		fieldTy := mappingFieldType(tc, target, atomic, key)
		val, _ := source.Get(key)
		converted, err := convert(tc, val, fieldTy, visiting)
		if err != nil {
			return nil, err
		}
		entries = append(entries, MapEntry{Key: key, Value: converted})
	}

	for _, name := range atomic.Names {
		if _, ok := seen[name]; ok {
			continue
		}
		if atomic.IsOptional(tc, name) {
			continue
		}
		// Neither a nil value nor a declared default is ever injected (default injection
		// is not yet supported), so a required field absent from source is always an error.
		return nil, missingRequiredField(tc, source, target, name)
	}

	readonly := semtypes.IsSubtype(tc, target, semtypes.VAL_READONLY)
	return NewMap(target, atomic, readonly, entries), nil
}

func mappingFieldType(tc semtypes.Context, target semtypes.SemType, atomic *semtypes.MappingAtomicType, key string) semtypes.SemType {
	for _, name := range atomic.Names {
		if name == key {
			return atomic.FieldInnerVal(key)
		}
	}
	return semtypes.MappingMemberTypeInnerVal(tc, target, semtypes.StringConst(key))
}

func tryConvertList(tc semtypes.Context, source *List, target semtypes.SemType, visiting map[BalValue]struct{}) (BalValue, *conversionFailure) {
	atomic := semtypes.ToListAtomicType(tc, target)

	fixedLen := atomic.Members.FixedLength
	if semtypes.IsNever(atomic.Rest()) {
		if source.Len() != fixedLen {
			return nil, incompatibleConversion(tc, source, target)
		}
	} else if source.Len() < fixedLen {
		return nil, incompatibleConversion(tc, source, target)
	}

	items := make([]BalValue, source.Len())
	for i := 0; i < source.Len(); i++ {
		memberTy := atomic.MemberAtInnerVal(i)
		converted, err := convert(tc, source.Get(i), memberTy, visiting)
		if err != nil {
			return nil, err
		}
		items[i] = converted
	}

	restFiller, _ := FillerFactoryFor(tc, atomic.Rest())
	readonly := semtypes.IsSubtype(tc, target, semtypes.VAL_READONLY)
	return NewList(target, atomic, readonly, restFiller, len(items), items), nil
}

func tryConvertBasicType(tc semtypes.Context, value BalValue, target semtypes.SemType) (BalValue, *conversionFailure) {
	valueTy := SemTypeForValue(value)
	if semtypes.IsSubtype(tc, valueTy, target) {
		return value, nil
	}
	switch value.(type) {
	case int64, float64, *decimal.Decimal:
		converted, numErr := convertNumeric(tc, value, target)
		if numErr != nil {
			return nil, numErr
		}
		if semtypes.IsSubtype(tc, SemTypeForValue(converted), target) {
			return converted, nil
		}
	}
	return nil, incompatibleConversion(tc, value, target)
}

func convertNumeric(tc semtypes.Context, value BalValue, target semtypes.SemType) (BalValue, *conversionFailure) {
	switch {
	case semtypes.IsSubtype(tc, target, semtypes.BYTE):
		n, err := NumericConvertToInt(value)
		if err != nil {
			return nil, newConversionFailure(err.Error())
		}
		if n >= 0 && n <= 255 {
			return n, nil
		}
		return nil, incompatibleConversion(tc, value, target)
	case semtypes.IsSubtypeSimple(target, semtypes.INT):
		n, err := NumericConvertToInt(value)
		if err != nil {
			return nil, newConversionFailure(err.Error())
		}
		return n, nil
	case semtypes.IsSubtypeSimple(target, semtypes.FLOAT):
		f, err := NumericConvertToFloat(value)
		if err != nil {
			return nil, newConversionFailure(err.Error())
		}
		return f, nil
	default: // DECIMAL
		d, err := NumericConvertToDecimal(value)
		if err != nil {
			return nil, newConversionFailure(err.Error())
		}
		return d, nil
	}
}

// conversionFailureFor reports why every candidate was rejected: structured values (maps/lists)
// surface per-candidate detail (the single reason, or a union of reasons), since that detail is
// often the only clue to which field or shape mismatched. Simple values get a single terse
// message, since per-candidate detail adds little for scalars.
func conversionFailureFor(tc semtypes.Context, value BalValue, target semtypes.SemType, children []*conversionFailure) *conversionFailure {
	if isStructuredValue(value) {
		if len(children) == 1 {
			return children[0]
		}
		if len(children) > 1 {
			return newUnionConversionFailure(children)
		}
	}
	return incompatibleConversion(tc, value, target)
}

func isStructuredValue(value BalValue) bool {
	switch value.(type) {
	case *List, *Map:
		return true
	default:
		return false
	}
}
