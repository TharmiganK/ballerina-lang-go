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

package codec

import (
	"bytes"
	"testing"

	"ballerina/bir"
	"ballerina/context"
	"ballerina/model"
	"ballerina/semtypes"
	"ballerina/values"
)

// Parameter annotations are intentionally inaccessible from Ballerina source;
// native dispatchers are their runtime consumer, so the codec carrier requires
// a direct Go assertion.
func TestParameterAnnotationsRoundTrip(t *testing.T) {
	typeEnv := semtypes.CreateTypeEnv()
	pkg := &bir.BIRPackage{
		PackageID:  model.DEFAULT,
		GlobalVars: make(map[string]bir.BIRGlobalVariableDcl),
		Functions: []bir.BIRFunction{{
			Name:              model.Name("annotated"),
			OriginalName:      model.Name("annotated"),
			FunctionLookupKey: "$anon/.:annotated",
			RequiredParams: []bir.BIRParameter{{
				Name:  model.Name("value"),
				Flags: model.FlagRequiredParam,
				Annotations: values.AnnotationValues{
					"test/meta:runtime": &values.RuntimeAnnotationValueRef{
						Organization: "test",
						Module:       "meta",
						GlobalName:   "$annotation$0",
					},
					"test/meta:value": "configured",
				},
			}},
		}},
	}

	data, err := Marshal(typeEnv, pkg)
	if err != nil {
		t.Fatalf("marshal BIR: %v", err)
	}
	second, err := Marshal(typeEnv, pkg)
	if err != nil {
		t.Fatalf("marshal BIR again: %v", err)
	}
	if !bytes.Equal(data, second) {
		t.Fatal("parameter annotation serialization is not deterministic")
	}

	env := context.NewCompilerEnvironment(semtypes.CreateTypeEnv(), false)
	decoded, err := Unmarshal(context.NewCompilerContext(env), data)
	if err != nil {
		t.Fatalf("unmarshal BIR: %v", err)
	}
	param := decoded.Functions[0].RequiredParams[0]
	if param.Name.Value() != "value" || param.Flags != model.FlagRequiredParam {
		t.Fatalf("parameter metadata did not round-trip: %#v", param)
	}
	if got := param.Annotations["test/meta:value"]; got != "configured" {
		t.Fatalf("constant annotation = %#v, want configured", got)
	}
	ref, ok := param.Annotations["test/meta:runtime"].(*values.RuntimeAnnotationValueRef)
	if !ok {
		t.Fatalf("runtime annotation reference has type %T", param.Annotations["test/meta:runtime"])
	}
	if ref.Organization != "test" || ref.Module != "meta" || ref.GlobalName != "$annotation$0" {
		t.Fatalf("runtime annotation reference did not round-trip: %#v", ref)
	}
}

// Service declaration annotations are consumed by native listeners through
// the generated service class, so their BIR carrier needs a direct assertion.
func TestClassAnnotationsRoundTrip(t *testing.T) {
	typeEnv := semtypes.CreateTypeEnv()
	pkg := &bir.BIRPackage{
		PackageID:  model.DEFAULT,
		GlobalVars: make(map[string]bir.BIRGlobalVariableDcl),
		ClassDefs: []bir.BIRClassDef{{
			Name:      model.Name("$service$0"),
			LookupKey: "$anon/.:$service$0",
			Annotations: values.AnnotationValues{
				"test/meta:runtime": &values.RuntimeAnnotationValueRef{
					Organization: "test",
					Module:       "meta",
					GlobalName:   "$annotation$0",
				},
				"test/meta:value": "configured",
			},
			VTable: make(map[string]*bir.BIRFunction),
			RTable: make(map[string][]bir.BIRResourceMethod),
		}},
	}

	data, err := Marshal(typeEnv, pkg)
	if err != nil {
		t.Fatalf("marshal BIR: %v", err)
	}
	second, err := Marshal(typeEnv, pkg)
	if err != nil {
		t.Fatalf("marshal BIR again: %v", err)
	}
	if !bytes.Equal(data, second) {
		t.Fatal("class annotation serialization is not deterministic")
	}

	env := context.NewCompilerEnvironment(semtypes.CreateTypeEnv(), false)
	decoded, err := Unmarshal(context.NewCompilerContext(env), data)
	if err != nil {
		t.Fatalf("unmarshal BIR: %v", err)
	}
	classDef := decoded.ClassDefs[0]
	if got := classDef.Annotations["test/meta:value"]; got != "configured" {
		t.Fatalf("constant annotation = %#v, want configured", got)
	}
	ref, ok := classDef.Annotations["test/meta:runtime"].(*values.RuntimeAnnotationValueRef)
	if !ok {
		t.Fatalf("runtime annotation reference has type %T", classDef.Annotations["test/meta:runtime"])
	}
	if ref.Organization != "test" || ref.Module != "meta" || ref.GlobalName != "$annotation$0" {
		t.Fatalf("runtime annotation reference did not round-trip: %#v", ref)
	}
}
