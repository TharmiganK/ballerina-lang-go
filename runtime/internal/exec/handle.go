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
	"fmt"

	"ballerina/bir"
	"ballerina/runtime/extern"
	"ballerina/runtime/internal/modules"
	"ballerina/values"
)

// InvokableHandle is provides a unified representation that can be used to execute any function/method
// in runtime
type InvokableHandle struct {
	invoke    func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error)
	signature func() (extern.FunctionSignature, bool)
	metadata  func(ctx *extern.Context) (extern.FunctionMetadata, bool)
}

func NewBIRHandle(fn *bir.BIRFunction) *InvokableHandle {
	return newBIRHandle(fn, nil)
}

func newBIRHandle(fn *bir.BIRFunction, parentFrame *Frame) *InvokableHandle {
	return newInvokableHandle(
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return executeFunction(ctx, fn, args, parentFrame), nil
		},
		fn,
		0,
	)
}

func NewNativeHandle(fn extern.NativeFunc) *InvokableHandle {
	return newNativeHandle(fn, nil)
}

func newNativeHandle(fn extern.NativeFunc, descriptor *bir.BIRFunction) *InvokableHandle {
	return newInvokableHandle(
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return fn(ctx, args)
		},
		descriptor,
		0,
	)
}

func NewFunctionValueHandle(env *extern.Env, fnValue *values.Function) (*InvokableHandle, error) {
	reg := env.Registry.(*modules.Registry)
	lookupKey := fnValue.LookupKey
	if builtin := reg.GetRuntimeBuiltin(lookupKey); builtin != nil {
		return NewNativeHandle(builtin), nil
	}
	if fn := reg.GetBIRFunction(lookupKey); fn != nil {
		return newBIRHandle(fn, parentFrameFromFunctionValue(fnValue)), nil
	}
	if externFn := reg.GetNativeFunction(lookupKey); externFn != nil {
		return newNativeHandle(externFn.Impl, reg.GetFunctionDescriptor(lookupKey)), nil
	}
	return nil, fmt.Errorf("function not found: %s", lookupKey)
}

func parentFrameFromFunctionValue(fnValue *values.Function) *Frame {
	if fnValue.ParentFrame == nil {
		return nil
	}
	return fnValue.ParentFrame.(*Frame)
}

func newResourceHandle(ctx *extern.Context, receiver *values.Object, match *values.ResourceEntry, path []values.BalValue) *InvokableHandle {
	descriptor := ctx.Env.Registry.(*modules.Registry).GetFunctionDescriptor(match.FunctionLookupKey)
	return newInvokableHandle(
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			full := buildResourceCallArgs(ctx, receiver, match, path, args)
			return lookupAndExecute(ctx, nil, full, match.FunctionLookupKey)
		},
		descriptor,
		resourcePathParamCount(match),
	)
}

func newInvokableHandle(
	invoke func(*extern.Context, []values.BalValue) (values.BalValue, error),
	descriptor *bir.BIRFunction,
	firstParam int,
) *InvokableHandle {
	handle := &InvokableHandle{invoke: invoke}
	if descriptor == nil {
		return handle
	}
	handle.signature = func() (extern.FunctionSignature, bool) {
		return describeFunctionSignature(descriptor, firstParam)
	}
	handle.metadata = func(ctx *extern.Context) (extern.FunctionMetadata, bool) {
		return describeFunctionMetadata(ctx, descriptor, firstParam)
	}
	return handle
}

func describeFunctionSignature(fn *bir.BIRFunction, firstParam int) (extern.FunctionSignature, bool) {
	if firstParam > len(fn.RequiredParams) || fn.ReturnVariable == nil {
		return extern.FunctionSignature{}, false
	}
	paramLocalOffset := fn.ParamLocalVarOffset()
	params := make([]extern.Parameter, len(fn.RequiredParams)-firstParam)
	for i := firstParam; i < len(fn.RequiredParams); i++ {
		localIndex := paramLocalOffset + i
		if localIndex >= len(fn.LocalVars) {
			return extern.FunctionSignature{}, false
		}
		params[i-firstParam] = extern.Parameter{
			Name: fn.RequiredParams[i].Name.Value(),
			Type: fn.LocalVars[localIndex].Type,
		}
	}
	signature := extern.FunctionSignature{Params: params, ReturnType: fn.ReturnVariable.Type}
	if fn.RestParams != nil {
		restLocalIndex := paramLocalOffset + len(fn.RequiredParams)
		if restLocalIndex >= len(fn.LocalVars) {
			return extern.FunctionSignature{}, false
		}
		signature.RestParam = &extern.Parameter{
			Name: fn.RestParams.Name.Value(),
			Type: fn.LocalVars[restLocalIndex].Type,
		}
	}
	return signature, true
}

func describeFunctionMetadata(ctx *extern.Context, fn *bir.BIRFunction, firstParam int) (extern.FunctionMetadata, bool) {
	if firstParam > len(fn.RequiredParams) || fn.ReturnVariable == nil {
		return extern.FunctionMetadata{}, false
	}
	params := make([]extern.ParameterMetadata, len(fn.RequiredParams)-firstParam)
	for i := firstParam; i < len(fn.RequiredParams); i++ {
		annotations, ok := resolveAnnotationValues(ctx, fn.RequiredParams[i].Annotations)
		if !ok {
			return extern.FunctionMetadata{}, false
		}
		params[i-firstParam] = extern.ParameterMetadata{Annotations: annotations}
	}
	metadata := extern.FunctionMetadata{Params: params}
	if fn.RestParams != nil {
		annotations, ok := resolveAnnotationValues(ctx, fn.RestParams.Annotations)
		if !ok {
			return extern.FunctionMetadata{}, false
		}
		metadata.RestParam = &extern.ParameterMetadata{Annotations: annotations}
	}
	return metadata, true
}

func FunctionSignature(_ *extern.Context, impl any) (extern.FunctionSignature, bool) {
	handle, ok := impl.(*InvokableHandle)
	if !ok || handle.signature == nil {
		return extern.FunctionSignature{}, false
	}
	return handle.signature()
}

func FunctionMetadata(ctx *extern.Context, impl any) (extern.FunctionMetadata, bool) {
	handle, ok := impl.(*InvokableHandle)
	if !ok || handle.metadata == nil {
		return extern.FunctionMetadata{}, false
	}
	return handle.metadata(ctx)
}
