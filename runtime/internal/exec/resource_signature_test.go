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

// Resource parameter metadata has no Ballerina-level accessor; native
// dispatchers consume this Go API directly, so it needs a boundary test here.
func TestResourceParamsReturnsNonPathParameterAnnotations(t *testing.T) {
	typeEnv := semtypes.CreateTypeEnv()
	registry := modules.NewRegistry(make(map[string]extern.NativeFunc))
	runtimeEnv := extern.InitEnv(pal.Platform{}, typeEnv, registry, extern.DispatchHandles{})
	ctx := extern.CreateContext(runtimeEnv)

	ref := &values.RuntimeAnnotationValueRef{
		Organization: "test",
		Module:       "meta",
		GlobalName:   "$annotation$0",
	}
	fn := bir.BIRFunction{
		Flags:             model.FlagAttached,
		FunctionLookupKey: "test/service:get",
		RequiredParams: []bir.BIRParameter{
			{Name: model.Name("path"), Annotations: values.NewAnnotationValues()},
			{Name: model.Name("header"), Annotations: values.AnnotationValues{"test/meta:constant": "configured"}},
			{Name: model.Name("payload"), Annotations: values.AnnotationValues{"test/meta:runtime": ref}},
		},
		RestParams: &bir.BIRParameter{
			Name:        model.Name("extras"),
			Annotations: values.AnnotationValues{"test/meta:marker": true},
		},
		LocalVars: make([]bir.BIRLocalVariableDcl, 6),
	}
	for i, name := range []string{"%0", "self", "path", "header", "payload", "extras"} {
		fn.LocalVars[i].SetName(model.Name(name))
	}
	pkg := &bir.BIRPackage{
		PackageID:  model.DEFAULT,
		GlobalVars: make(map[string]bir.BIRGlobalVariableDcl),
		Functions:  []bir.BIRFunction{fn},
	}
	registry.RegisterModule(pkg.PackageID, modules.NewBIRModule(semtypes.ContextFrom(typeEnv), pkg))

	metaID := model.NewPackageID(model.DefaultPackageIDInterner, model.Name("test"), []model.Name{model.Name("meta")}, model.DEFAULT_VERSION)
	metaModule := modules.NewBIRModule(semtypes.ContextFrom(typeEnv), &bir.BIRPackage{
		PackageID:  metaID,
		GlobalVars: make(map[string]bir.BIRGlobalVariableDcl),
	})
	metaModule.Globals[ref.GlobalLookupKey()] = "runtime-value"
	registry.RegisterModule(metaID, metaModule)

	entry := &values.ResourceEntry{
		PathSegments:      []values.ResourcePathSegmentDef{{Ty: semtypes.STRING}},
		RestSegmentTy:     semtypes.NEVER,
		FunctionLookupKey: fn.FunctionLookupKey,
	}
	handle := newResourceHandle(nil, entry, nil)
	signature, ok := ResourceParams(ctx, handle)
	if !ok {
		t.Fatal("resource signature was not available")
	}
	if got, want := len(signature.Params), resourceExtraArgCount(ctx, entry); got != want {
		t.Fatalf("parameter descriptor count = %d, extra argument count = %d", got, want)
	}
	if signature.Params[0].Name != "header" || signature.Params[0].Annotations["test/meta:constant"] != "configured" {
		t.Fatalf("constant parameter annotation was not retained: %#v", signature.Params[0])
	}
	if signature.Params[1].Name != "payload" || signature.Params[1].Annotations["test/meta:runtime"] != "runtime-value" {
		t.Fatalf("runtime parameter annotation was not resolved: %#v", signature.Params[1])
	}
	if signature.RestParam == nil || signature.RestParam.Name != "extras" || signature.RestParam.Annotations["test/meta:marker"] != true {
		t.Fatalf("rest parameter annotation was not retained: %#v", signature.RestParam)
	}

	if _, ok := ResourceParams(ctx, NewBIRHandle(&fn)); ok {
		t.Fatal("ordinary function handle unexpectedly exposed a resource signature")
	}
}
