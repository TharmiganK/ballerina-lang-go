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

# Returns the current working directory.
#
# + return - Current working directory or else an empty string if the current working directory cannot be determined
public isolated function getCurrentDir() returns string = external;

# Creates a new directory with the specified name.
#
# + dir - Directory name
# + option - Indicates whether the `createDir` should create non-existing parent directories. The default is only to
#            create the given current directory.
# + return - A `file:Error` if the directory creation failed
public isolated function createDir(string dir, DirOption option = NON_RECURSIVE) returns Error? = external;

# Removes the specified file or directory.
#
# + path - String value of the file/directory path
# + option - Indicates whether the `remove` should recursively remove all the files inside the given directory
# + return - An `file:Error` if failed to remove
public isolated function remove(string path, DirOption option = NON_RECURSIVE) returns Error? = external;

# Renames (moves) the old path with the new path.
# If the new path already exists and it is not a directory, this replaces the file.
#
# + oldPath - String value of the old file path
# + newPath - String value of the new file path
# + return - An `file:Error` if failed to rename
public isolated function rename(string oldPath, string newPath) returns Error? = external;

# Creates a file in the specified file path.
# Truncates if the file already exists in the given path.
#
# + path - String value of the file path
# + return - A `file:Error` if file creation failed
public isolated function create(string path) returns Error? = external;

isolated function getRawMetaData(string path) returns MetaData|Error = external;

# Returns the metadata information of the file specified in the file path.
#
# + path - String value of the file path.
# + return - The `MetaData` instance with the file metadata or else a `file:Error`
public isolated function getMetaData(string path) returns MetaData|Error {
    return getRawMetaData(path);
}

isolated function readDirRaw(string path) returns MetaData[]|Error = external;

# Reads the directory and returns a list of metadata of files and directories
# inside the specified directory.
#
# + path - String value of the directory path
# + return - The `MetaData` array or else a `file:Error` if there is an error
public isolated function readDir(string path) returns MetaData[]|Error {
    return readDirRaw(path);
}

# Copy the file/directory in the old path to the new path.
#
# + sourcePath - String value of the old file path
# + destinationPath - String value of the new file path
# + options - Parameter to denote how the copy operation should be done. Supported options are,
#  `REPLACE_EXISTING` - Replace the target path if it already exists,
#  `COPY_ATTRIBUTES` - Copy the file attributes as well to the target,
#  `NO_FOLLOW_LINKS` - If source is a symlink, only the link is copied, not the target of the link.
# + return - An `file:Error` if failed to copy
public isolated function copy(string sourcePath, string destinationPath, CopyOption... options) returns Error? = external;

# Creates a temporary file.
#
# + suffix - Optional file suffix
# + prefix - Optional file prefix
# + dir - The directory path where the temp file should be created. If not specified,
#         temp file will be created in the default temp directory of the OS.
# + return - Temporary file path or else a `file:Error` if there is an error
public isolated function createTemp(string? suffix = (), string? prefix = (), string? dir = ()) returns string|Error = external;

# Creates a temporary directory.
#
# + suffix - Optional directory suffix
# + prefix - Optional directory prefix
# + dir - The directory path where the temp directory should be created. If not specified, temp directory
#         will be created in the default temp directory of the OS.
# + return - Temporary directory path or else a `file:Error` if there is an error
public isolated function createTempDir(string? suffix = (), string? prefix = (), string? dir = ()) returns string|Error = external;

# Tests a file path against a test condition.
#
# + path - String value of the file path
# + testOption - The option to be tested upon the path. Supported options are,
#  `EXISTS` - Test whether a file path exists,
#  `IS_DIR` - Test whether a file path is a directory,
#  `IS_SYMLINK` - Test whether a file path is a symlink,
#  `READABLE` - Test whether a file path is readable,
#  `WRITABLE` - Test whether a file path is writable.
# + return - True/false depending on the option to be tested or else a `file:Error` if there is an error
public isolated function test(string path, TestOption testOption) returns boolean|Error = external;
