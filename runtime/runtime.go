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

package runtime

import (
	"os"
	"os/signal"
	"sync"
	"syscall"

	"ballerina-lang-go/bir"
	"ballerina-lang-go/model"
	"ballerina-lang-go/platform/pal"
	"ballerina-lang-go/runtime/extern"
	"ballerina-lang-go/runtime/internal/exec"
	"ballerina-lang-go/runtime/internal/modules"
	"ballerina-lang-go/semtypes"
	"ballerina-lang-go/values"
)

var dispatchHooks = extern.DispatchHandles{
	LookupObject:   exec.LookupObjectMethod,
	LookupRemote:   exec.LookupRemoteMethod,
	LookupResource: exec.LookupResourceMethod,
	Invoke:         exec.InvokeMethod,
}

// Runtime represents a Ballerina runtime instance that owns a module registry
// and is used as the execution context for interpreting BIR packages.
type Runtime struct {
	env          *extern.Env
	cleanup      []func()
	listenerWg   sync.WaitGroup
	listenerMu   sync.Mutex
	listenerStop []func()
}

// ModuleInitializer is a function that can install modules (e.g. stdlibs) into
// a runtime instance during its construction.
type ModuleInitializer func(*Runtime)

var moduleInitializers []ModuleInitializer

// NewRuntime constructs a new runtime with an empty registry and runs all
// registered module initializers.
func NewRuntime(platform pal.Platform, tyEnv semtypes.Env) *Runtime {
	registry := modules.NewRegistry()
	env := extern.InitEnv(platform, tyEnv, registry, dispatchHooks)
	rt := &Runtime{env: env}
	for _, init := range moduleInitializers {
		init(rt)
	}
	return rt
}

// Platform returns the platform configuration of this runtime instance.
func (rt *Runtime) Platform() pal.Platform {
	return rt.env.Platform
}

func (rt *Runtime) registry() *modules.Registry {
	return rt.env.Registry.(*modules.Registry)
}

// RegisterCleanup registers a function to be called after Interpret returns,
// regardless of whether it succeeds or fails. Used to release resources such
// as listening sockets between test runs.
func (rt *Runtime) RegisterCleanup(fn func()) {
	rt.cleanup = append(rt.cleanup, fn)
}

// RegisterActiveListener increments the active-listener wait group and stores
// stopFn so it can be called on SIGINT/SIGTERM. ListenerDone must be called
// once the corresponding server goroutine exits.
func (rt *Runtime) RegisterActiveListener(stopFn func()) {
	rt.listenerWg.Add(1)
	rt.listenerMu.Lock()
	rt.listenerStop = append(rt.listenerStop, stopFn)
	rt.listenerMu.Unlock()
}

// ListenerDone decrements the active-listener wait group. It must be called by
// each server goroutine when its Serve call returns (whether due to Close,
// gracefulStop, or any other reason).
func (rt *Runtime) ListenerDone() {
	rt.listenerWg.Done()
}

// Interpret interprets a BIR package using this runtime instance.
func (rt *Runtime) Interpret(pkg bir.BIRPackage) (err error) {
	defer func() {
		for _, fn := range rt.cleanup {
			fn()
		}
		rt.cleanup = nil
	}()
	if err = exec.Interpret(pkg, rt.env); err != nil {
		return
	}
	rt.waitForListeners()
	return
}

// waitForListeners blocks until all active listeners have stopped or a
// SIGINT/SIGTERM is received. On signal it calls each registered stop function
// and then waits for the goroutines to drain. If there are no active listeners
// it returns immediately.
func (rt *Runtime) waitForListeners() {
	done := make(chan struct{})
	go func() { rt.listenerWg.Wait(); close(done) }()
	select {
	case <-done:
		return
	default:
	}
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(sigCh)
	select {
	case <-done:
	case <-sigCh:
		rt.listenerMu.Lock()
		stops := make([]func(), len(rt.listenerStop))
		copy(stops, rt.listenerStop)
		rt.listenerMu.Unlock()
		for _, stop := range stops {
			stop()
		}
		rt.listenerWg.Wait()
	}
}

// RegisterModuleInitializer registers a module initializer that will be invoked
// for every newly created runtime.
func RegisterModuleInitializer(init ModuleInitializer) {
	moduleInitializers = append(moduleInitializers, init)
}

// NewExternContext creates a properly initialised extern.Context with a fresh
// call stack. Use this when dispatching Ballerina code from outside the main
// interpreter loop, such as from HTTP handler goroutines. Each concurrent
// execution path must have its own context.
func (rt *Runtime) NewExternContext() *extern.Context {
	return exec.NewContext(rt.env)
}

// GetBIRFunctionParamCount returns the number of required parameters of the BIR
// function with the given lookup key, not counting the receiver. Returns -1 if
// the function has no BIR body (extern-only native functions).
// For resource methods this count includes both path-param parameters and any
// extra user-supplied parameters.
func GetBIRFunctionParamCount(ctx *extern.Context, lookupKey string) int {
	fn := ctx.Env.Registry.(*modules.Registry).GetBIRFunction(lookupKey)
	if fn == nil {
		return -1
	}
	return len(fn.RequiredParams)
}

// GetTypeEnv returns the semantic type environment.
func (rt *Runtime) GetTypeEnv() semtypes.Env {
	return rt.env.TypeEnv
}

// RegisterExternFunction registers a native (extern) function implementation in
// the given runtime instance so it can be called from interpreted BIR code.
func RegisterExternFunction(rt *Runtime, orgName string, moduleName string, funcName string, impl extern.NativeFunc) {
	rt.registry().RegisterExternFunction(orgName, moduleName, funcName, impl)
}

// RegisterExternClassDef registers a synthetic BIRClassDef for a Go-declared class so
// that execNewObject can resolve it. VTable entries have no BIR body; exec falls through
// to nativeFunctions for method dispatch.
func RegisterExternClassDef(rt *Runtime, def *bir.BIRClassDef) {
	rt.registry().RegisterExternClassDef(def)
}

// RegisterModuleGlobals makes module-level constants accessible at runtime.
// When Ballerina source code accesses an extern package's constant (e.g. http:LEADING),
// the BIR executor looks it up as a global variable in that package's module. Without
// registration, GetModule returns nil and causes a nil dereference panic.
func RegisterModuleGlobals(rt *Runtime, pkgId *model.PackageID, globals map[string]values.BalValue) {
	if existing := rt.registry().GetModule(pkgId); existing != nil {
		if existing.Globals == nil {
			existing.Globals = make(map[string]values.BalValue)
		}
		for k, v := range globals {
			existing.Globals[k] = v
		}
		return
	}
	rt.registry().RegisterModule(pkgId, &modules.BIRModule{Globals: globals})
}

// LoadPlatformModule registers an embedded platform BIR package and runs its init.
func LoadPlatformModule(rt *Runtime, pkg *bir.BIRPackage) {
	exec.LoadPlatformModule(rt.env, pkg)
}
