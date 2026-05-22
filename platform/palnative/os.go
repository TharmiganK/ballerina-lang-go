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

package palnative

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"os/user"
	"strings"
	"sync"

	"ballerina-lang-go/platform/pal"
)

type nativeProcess struct {
	cmd      *exec.Cmd
	stdout   bytes.Buffer
	stderr   bytes.Buffer
	waitOnce sync.Once
	exitCode int
	waitErr  error
}

func (p *nativeProcess) ensureWait() {
	p.waitOnce.Do(func() {
		err := p.cmd.Wait()
		if err == nil {
			p.exitCode = 0
			return
		}
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			p.exitCode = exitErr.ExitCode()
		} else {
			p.exitCode = -1
			p.waitErr = err
		}
	})
}

func (p *nativeProcess) WaitForExit() (int, error) {
	p.ensureWait()
	return p.exitCode, p.waitErr
}

func (p *nativeProcess) ReadStdout() ([]byte, error) {
	p.ensureWait()
	return p.stdout.Bytes(), nil
}

func (p *nativeProcess) ReadStderr() ([]byte, error) {
	p.ensureWait()
	return p.stderr.Bytes(), nil
}

func (p *nativeProcess) Kill() {
	_ = p.cmd.Process.Kill()
}

// NewNativeOSPAL returns a pal.OS backed by the host operating system.
func NewNativeOSPAL() pal.OS { return newNativeOSPAL() }

func newNativeOSPAL() pal.OS {
	return pal.OS{
		GetEnv:  os.Getenv,
		SetEnv:  os.Setenv,
		UnsetEnv: os.Unsetenv,
		ListEnv: func() map[string]string {
			result := make(map[string]string)
			for _, entry := range os.Environ() {
				if idx := strings.IndexByte(entry, '='); idx >= 0 {
					result[entry[:idx]] = entry[idx+1:]
				}
			}
			return result
		},
		GetUsername: func() string {
			u, err := user.Current()
			if err != nil {
				return ""
			}
			return u.Username
		},
		GetUserHome: func() string {
			u, err := user.Current()
			if err != nil {
				return ""
			}
			return u.HomeDir
		},
		Exec: func(command string, args []string, envOverride map[string]string) (pal.ProcessHandle, error) {
			cmd := exec.Command(command, args...)
			if len(envOverride) > 0 {
				envMap := make(map[string]string)
				for _, entry := range os.Environ() {
					if idx := strings.IndexByte(entry, '='); idx >= 0 {
						envMap[entry[:idx]] = entry[idx+1:]
					}
				}
				for k, v := range envOverride {
					envMap[k] = v
				}
				merged := make([]string, 0, len(envMap))
				for k, v := range envMap {
					merged = append(merged, k+"="+v)
				}
				cmd.Env = merged
			}
			proc := &nativeProcess{cmd: cmd}
			cmd.Stdout = &proc.stdout
			cmd.Stderr = &proc.stderr
			if err := cmd.Start(); err != nil {
				return nil, err
			}
			return proc, nil
		},
	}
}
