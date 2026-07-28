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

package main

import "testing"

func thrSamples(vals ...float64) []sample {
	out := make([]sample, len(vals))
	for i, v := range vals {
		out[i] = sample{wrkMetrics: wrkMetrics{throughput: v}}
	}
	return out
}

func TestGateFlagsSignificantRegression(t *testing.T) {
	cfg := config{repeats: 3, duration: "10s", conns: 50, threshold: 10}
	base := thrSamples(100000, 101000, 99000) // median 100000
	head := thrSamples(85000, 86000, 84000)   // median 85000 -> -15%
	_, res := buildReport("base", "head", base, head, cfg)
	if !res.Regressed {
		t.Errorf("expected regressed=true for -15%% at threshold 10%%")
	}
	if res.ThroughputDelta != -15 {
		t.Errorf("throughputDelta = %v, want -15", res.ThroughputDelta)
	}
}

func TestGatePassesWithinThreshold(t *testing.T) {
	cfg := config{repeats: 3, duration: "10s", conns: 50, threshold: 10}
	base := thrSamples(100000, 101000, 99000) // median 100000
	head := thrSamples(95000, 96000, 94000)   // median 95000 -> -5%
	_, res := buildReport("base", "head", base, head, cfg)
	if res.Regressed {
		t.Errorf("expected regressed=false for -5%% at threshold 10%%")
	}
	if res.ThroughputDelta != -5 {
		t.Errorf("throughputDelta = %v, want -5", res.ThroughputDelta)
	}
}

func TestGateIgnoresImprovement(t *testing.T) {
	cfg := config{repeats: 2, duration: "10s", conns: 50, threshold: 10}
	base := thrSamples(100000, 100000)
	head := thrSamples(120000, 120000) // +20% — never a regression
	_, res := buildReport("base", "head", base, head, cfg)
	if res.Regressed {
		t.Errorf("an improvement must not be flagged as a regression")
	}
}

func TestComma(t *testing.T) {
	cases := map[float64]string{0: "0", 999: "999", 1000: "1,000", 69303: "69,303", 1234567: "1,234,567"}
	for in, want := range cases {
		if got := comma(in); got != want {
			t.Errorf("comma(%v) = %q, want %q", in, got, want)
		}
	}
}
