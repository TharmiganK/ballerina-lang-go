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

// Seconds holds a decimal value representing seconds.
public type Seconds decimal;

// Utc is a point on the UTC time-scale represented as [int, decimal].
// The first member is integral seconds from the UNIX epoch; the second is the fractional seconds.
public type Utc [int, decimal];

public const int SUNDAY = 0;
public const int MONDAY = 1;
public const int TUESDAY = 2;
public const int WEDNESDAY = 3;
public const int THURSDAY = 4;
public const int FRIDAY = 5;
public const int SATURDAY = 6;

// DayOfWeek represents a day of the week (0=Sunday .. 6=Saturday).
public type DayOfWeek SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY;

type DateFields record {
    int year;
    int month;
    int day;
};

type TimeOfDayFields record {
    int hour;
    int minute;
    Seconds second?;
};

type OptionalDateFields record {
    int year?;
    int month?;
    int day?;
};

type OptionalTimeOfDayFields record {
    int hour?;
    int minute?;
    Seconds second?;
};

// Date is a date in the proleptic Gregorian calendar.
public type Date record {
    *DateFields;
    *OptionalTimeOfDayFields;
    ZoneOffset utcOffset?;
};

// TimeOfDay is a time within a day.
public type TimeOfDay record {
    *OptionalDateFields;
    *TimeOfDayFields;
    ZoneOffset utcOffset?;
};

// ZoneOffset is a fixed UTC zone offset.
public type ZoneOffset record {|
    int hours;
    int minutes = 0;
    decimal seconds?;
|};

type ReadWriteZoneOffset record {|
    int hours;
    int minutes = 0;
    decimal seconds?;
|};

// Z represents the UTC zone offset (hours=0, minutes=0).
public final ZoneOffset Z = {hours: 0};

// ZERO_OR_ONE is either 0 or 1.
public type ZERO_OR_ONE 0|1;

// Civil is a date-time in a civil time zone.
public type Civil record {
    *DateFields;
    *TimeOfDayFields;
    ZoneOffset utcOffset?;
    string timeAbbrev?;
    ZERO_OR_ONE which?;
    DayOfWeek dayOfWeek?;
};

// UtcZoneHandling controls the zone string used in utcToEmailString.
public type UtcZoneHandling "0"|"GMT"|"UT"|"Z";

// Duration represents a time duration for adjusting civil date-time values.
public type Duration record {|
    int years = 0;
    int months = 0;
    int weeks = 0;
    int days = 0;
    int hours = 0;
    int minutes = 0;
    Seconds seconds = 0.0;
|};

// HeaderZoneHandling indicates how to handle zone offset vs time abbreviation in header formats.
public enum HeaderZoneHandling {
    PREFER_TIME_ABBREV,
    PREFER_ZONE_OFFSET,
    ZONE_OFFSET_WITH_TIME_ABBREV_COMMENT
}
