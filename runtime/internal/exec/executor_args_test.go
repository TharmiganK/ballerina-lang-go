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
	runtimeframe "ballerina/runtime/internal/frame"
	"ballerina/values"
)

// A well-typed Ballerina call cannot have too few arguments after desugaring,
// but native dispatchers can supply a malformed argument slice directly.
func TestInitLocalsRejectsShortArgumentListWithBallerinaError(t *testing.T) {
	tests := []struct {
		name  string
		flags model.Flag
		args  []values.BalValue
	}{
		{name: "top-level"},
		{name: "attached", flags: model.FlagAttached, args: []values.BalValue{"self"}},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			fn := &bir.BIRFunction{
				Flags: test.flags,
				RequiredParams: []bir.BIRParameter{{
					Name:        model.Name("value"),
					Annotations: values.NewAnnotationValues(),
				}},
			}
			fn.LocalVars = make([]bir.BIRLocalVariableDcl, fn.ParamLocalVarOffset()+1)
			frame := runtimeframe.New(len(fn.LocalVars), nil)
			defer frame.Free()

			recovered := panicFromInitLocals(fn, test.args, frame)
			errValue, ok := recovered.(*values.Error)
			if !ok {
				t.Fatalf("short argument list panicked with %T, want *values.Error", recovered)
			}
			if errValue.Message != "not enough arguments" {
				t.Fatalf("error message = %q, want not enough arguments", errValue.Message)
			}
		})
	}
}

func panicFromInitLocals(fn *bir.BIRFunction, args []values.BalValue, frame *Frame) (recovered any) {
	defer func() {
		recovered = recover()
	}()
	initLocalsForFunction(nil, fn, args, frame)
	return nil
}
