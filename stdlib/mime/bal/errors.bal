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

// Note: distinct error types are not yet supported; all subtypes are plain error aliases.
public type Error error;

public type EncodeError error;

public type DecodeError error;

public type GenericMimeError error;

public type SetHeaderError error;

public type InvalidHeaderValueError error;

public type InvalidHeaderParamError error;

public type InvalidContentLengthError error;

public type HeaderNotFoundError error;

public type InvalidHeaderOperationError error;

public type SerializationError error;

public type ParserError error;

public type InvalidContentTypeError error;

public type HeaderUnavailableError error;

public type IdleTimeoutTriggeredError error;

public type NoContentError error;
