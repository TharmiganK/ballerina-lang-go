// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
//
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
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"ballerina-lang-go/platform/pal"
)

// NewNativeFSPAL returns a pal.FS backed by the host OS filesystem.
func NewNativeFSPAL() pal.FS {
	return newNativeFSPAL()
}

func newNativeFSPAL() pal.FS {
	return pal.FS{
		ReadFile: func(path string) ([]byte, error) {
			return os.ReadFile(path)
		},
		WriteFile: func(path string, data []byte) error {
			return os.WriteFile(path, data, 0o644)
		},
		AppendFile: func(path string, data []byte) error {
			f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
			if err != nil {
				return err
			}
			defer f.Close()
			_, err = f.Write(data)
			return err
		},
		Getwd: os.Getwd,
		Mkdir: func(path string) error {
			return os.Mkdir(path, 0o755)
		},
		MkdirAll: func(path string) error {
			return os.MkdirAll(path, 0o755)
		},
		Remove: func(path string) error {
			return os.Remove(path)
		},
		RemoveAll: func(path string) error {
			return os.RemoveAll(path)
		},
		Rename: os.Rename,
		CreateFile: func(path string) error {
			f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
			if err != nil {
				return err
			}
			return f.Close()
		},
		Stat: func(path string) (*pal.FileInfo, error) {
			fi, err := os.Stat(path)
			if err != nil {
				return nil, err
			}
			absPath, _ := filepath.Abs(path)
			return &pal.FileInfo{
				AbsPath:    absPath,
				Size:       fi.Size(),
				ModifiedAt: fi.ModTime(),
				IsDir:      fi.IsDir(),
				IsSymlink:  false,
				IsReadable: isReadable(path, fi),
				IsWritable: isWritable(path, fi),
			}, nil
		},
		Lstat: func(path string) (*pal.FileInfo, error) {
			fi, err := os.Lstat(path)
			if err != nil {
				return nil, err
			}
			absPath, _ := filepath.Abs(path)
			return &pal.FileInfo{
				AbsPath:    absPath,
				Size:       fi.Size(),
				ModifiedAt: fi.ModTime(),
				IsDir:      fi.IsDir(),
				IsSymlink:  fi.Mode()&os.ModeSymlink != 0,
				IsReadable: isReadable(path, fi),
				IsWritable: isWritable(path, fi),
			}, nil
		},
		ReadDir: func(path string) ([]pal.FileInfo, error) {
			entries, err := os.ReadDir(path)
			if err != nil {
				return nil, err
			}
			result := make([]pal.FileInfo, 0, len(entries))
			for _, entry := range entries {
				childPath := filepath.Join(path, entry.Name())
				fi, err := entry.Info()
				if err != nil {
					continue
				}
				absPath, _ := filepath.Abs(childPath)
				result = append(result, pal.FileInfo{
					AbsPath:    absPath,
					Size:       fi.Size(),
					ModifiedAt: fi.ModTime(),
					IsDir:      fi.IsDir(),
					IsSymlink:  fi.Mode()&os.ModeSymlink != 0,
					IsReadable: isReadable(childPath, fi),
					IsWritable: isWritable(childPath, fi),
				})
			}
			return result, nil
		},
		Copy:          nativeCopyFS,
		CreateTemp:    nativeCreateTemp,
		CreateTempDir: nativeCreateTempDir,
		Readlink:      os.Readlink,
	}
}

func isReadable(path string, _ os.FileInfo) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	f.Close()
	return true
}

func isWritable(path string, fi os.FileInfo) bool {
	if fi.IsDir() {
		return fi.Mode().Perm()&0o222 != 0
	}
	f, err := os.OpenFile(path, os.O_WRONLY, 0)
	if err != nil {
		return false
	}
	f.Close()
	return true
}

func nativeCreateTemp(prefix, suffix, dir string) (string, error) {
	if dir == "" {
		dir = os.TempDir()
	}
	f, err := os.CreateTemp(dir, prefix+"*"+suffix)
	if err != nil {
		return "", err
	}
	name := f.Name()
	f.Close()
	abs, _ := filepath.Abs(name)
	return abs, nil
}

func nativeCreateTempDir(prefix, suffix, dir string) (string, error) {
	if dir == "" {
		dir = os.TempDir()
	}
	path, err := os.MkdirTemp(dir, prefix+"*"+suffix)
	if err != nil {
		return "", err
	}
	return filepath.Abs(path)
}

func nativeCopyFS(src, dst string, opts pal.CopyOptions) error {
	srcInfo, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if srcInfo.Mode()&os.ModeSymlink != 0 && opts.NoFollowLinks {
		target, err := os.Readlink(src)
		if err != nil {
			return err
		}
		if opts.ReplaceExisting {
			os.Remove(dst)
		}
		return os.Symlink(target, dst)
	}
	if srcInfo.IsDir() {
		return nativeCopyDir(src, dst, opts)
	}
	return nativeCopyFile(src, dst, opts)
}

func nativeCopyDir(src, dst string, opts pal.CopyOptions) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			if mkErr := os.MkdirAll(target, 0o755); mkErr != nil && !os.IsExist(mkErr) {
				return mkErr
			}
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 && opts.NoFollowLinks {
			linkTarget, err := os.Readlink(path)
			if err != nil {
				return err
			}
			if opts.ReplaceExisting {
				os.Remove(target)
			}
			return os.Symlink(linkTarget, target)
		}
		return nativeCopyFile(path, target, opts)
	})
}

func nativeCopyFile(src, dst string, opts pal.CopyOptions) error {
	if !opts.ReplaceExisting {
		if _, err := os.Lstat(dst); err == nil {
			return &os.PathError{Op: "copy", Path: dst, Err: os.ErrExist}
		}
	}
	srcF, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcF.Close()
	dstF, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstF.Close()
	if _, err := io.Copy(dstF, srcF); err != nil {
		return err
	}
	if opts.CopyAttributes {
		if info, err := os.Stat(src); err == nil {
			os.Chmod(dst, info.Mode())
		}
	}
	return nil
}
