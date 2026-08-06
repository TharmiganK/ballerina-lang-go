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

package exec

import (
	"testing"

	"ballerina/bir"
	"ballerina/model"
	"ballerina/platform/pal"
	"ballerina/runtime/extern"
	"ballerina/runtime/internal/modules"
	"ballerina/semtypes"
	"ballerina/values"
)

// Service annotations have no Ballerina-level accessor. Native listener
// implementations consume this API directly, so it needs a boundary test.
func TestObjectAnnotationsResolvesRuntimeValues(t *testing.T) {
	typeEnv := semtypes.CreateTypeEnv()
	registry := modules.NewRegistry(make(map[string]extern.NativeFunc))
	runtimeEnv := extern.InitEnv(pal.Platform{}, typeEnv, registry, extern.DispatchHandles{
		ObjectAnnotations: ObjectAnnotations,
	})
	ctx := extern.CreateContext(runtimeEnv)

	ref := &values.RuntimeAnnotationValueRef{
		Organization: "test",
		Module:       "meta",
		GlobalName:   "$annotation$0",
	}
	metaID := model.NewPackageID(model.DefaultPackageIDInterner, model.Name("test"), []model.Name{model.Name("meta")}, model.DEFAULT_VERSION)
	metaModule := modules.NewBIRModule(semtypes.ContextFrom(typeEnv), &bir.BIRPackage{
		PackageID:  metaID,
		GlobalVars: make(map[string]bir.BIRGlobalVariableDcl),
	})
	metaModule.Globals[ref.GlobalLookupKey()] = "runtime-value"
	registry.RegisterModule(metaID, metaModule)

	obj := values.NewObject(semtypes.OBJECT, nil, nil, nil, values.AnnotationValues{
		"test/meta:constant": "configured",
		"test/meta:runtime":  ref,
	})
	annotations, ok := ctx.ObjectAnnotations(obj)
	if !ok {
		t.Fatal("object annotations were not available")
	}
	if annotations["test/meta:constant"] != "configured" {
		t.Fatalf("constant annotation was not retained: %#v", annotations)
	}
	if annotations["test/meta:runtime"] != "runtime-value" {
		t.Fatalf("runtime annotation was not resolved: %#v", annotations)
	}
}
