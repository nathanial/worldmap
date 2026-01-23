/-
  Tests for Worldmap.RetryLogic
-/
import Crucible
import Worldmap.RetryLogic

namespace WorldmapTests.RetryLogicTests

open Crucible
open Worldmap.RetryLogic

testSuite "RetryLogic"

def testConfig : RetryConfig := { maxRetries := 3, baseDelay := 60 }

test "initialFailure sets retryCount to 0" := do
  let rs := RetryState.initialFailure 100
  shouldBe rs.retryCount 0

test "initialFailure records lastFailTime" := do
  let rs := RetryState.initialFailure 100
  shouldBe rs.lastFailTime 100

test "initialFailure stores error message" := do
  let rs := RetryState.initialFailure 100 "Connection refused"
  shouldBe rs.errorMessage "Connection refused"

test "recordRetryFailure increments count" := do
  let rs := RetryState.initialFailure 100
  let rs' := rs.recordRetryFailure 200
  shouldBe rs'.retryCount 1

test "recordRetryFailure updates lastFailTime" := do
  let rs := RetryState.initialFailure 100
  let rs' := rs.recordRetryFailure 200
  shouldBe rs'.lastFailTime 200

test "backoffDelay uses exponential backoff" := do
  let rs0 := RetryState.initialFailure 0
  let rs1 := rs0.recordRetryFailure 0
  let rs2 := rs1.recordRetryFailure 0
  -- baseDelay = 60
  -- retry 0: 60 * 2^0 = 60
  -- retry 1: 60 * 2^1 = 120
  -- retry 2: 60 * 2^2 = 240
  shouldBe (rs0.backoffDelay testConfig) 60
  shouldBe (rs1.backoffDelay testConfig) 120
  shouldBe (rs2.backoffDelay testConfig) 240

test "nextRetryTime is lastFailTime + backoffDelay" := do
  let rs := RetryState.initialFailure 100
  shouldBe (rs.nextRetryTime testConfig) (100 + 60)

test "isExhausted returns false when retries remain" := do
  let rs := RetryState.initialFailure 0
  shouldBe (rs.isExhausted testConfig) false

test "isExhausted returns true when maxRetries reached" := do
  let rs := iterateFailures 0 3 (RetryState.initialFailure 0)
  shouldBe (rs.isExhausted testConfig) true

test "shouldRetry returns false before delay expires" := do
  let rs := RetryState.initialFailure 100
  -- Next retry time is 100 + 60 = 160
  shouldBe (rs.shouldRetry testConfig 150) false

test "shouldRetry returns true after delay expires" := do
  let rs := RetryState.initialFailure 100
  -- Next retry time is 100 + 60 = 160
  shouldBe (rs.shouldRetry testConfig 160) true
  shouldBe (rs.shouldRetry testConfig 200) true

test "shouldRetry returns false when exhausted" := do
  let rs := iterateFailures 0 3 (RetryState.initialFailure 0)
  shouldBe (rs.shouldRetry testConfig 1000) false

test "iterateFailures applies n failures" := do
  let rs := iterateFailures 0 2 (RetryState.initialFailure 0)
  shouldBe rs.retryCount 2

test "exponential backoff grows correctly" := do
  let rs0 := RetryState.initialFailure 0
  let rs1 := rs0.recordRetryFailure 0
  let rs2 := rs1.recordRetryFailure 0
  let rs3 := rs2.recordRetryFailure 0
  -- Check that delays double each time
  let d0 := rs0.backoffDelay testConfig
  let d1 := rs1.backoffDelay testConfig
  let d2 := rs2.backoffDelay testConfig
  let d3 := rs3.backoffDelay testConfig
  shouldBe d1 (d0 * 2)
  shouldBe d2 (d1 * 2)
  shouldBe d3 (d2 * 2)

test "retry timing with different base delays" := do
  let fastConfig : RetryConfig := { maxRetries := 3, baseDelay := 10 }
  let slowConfig : RetryConfig := { maxRetries := 3, baseDelay := 100 }
  let rs := RetryState.initialFailure 0
  shouldBe (rs.backoffDelay fastConfig) 10
  shouldBe (rs.backoffDelay slowConfig) 100

test "retry exhaustion with different max retries" := do
  let config1 : RetryConfig := { maxRetries := 1, baseDelay := 60 }
  let config5 : RetryConfig := { maxRetries := 5, baseDelay := 60 }
  let rs1 := iterateFailures 0 1 (RetryState.initialFailure 0)
  let rs3 := iterateFailures 0 3 (RetryState.initialFailure 0)
  shouldBe (rs1.isExhausted config1) true
  shouldBe (rs1.isExhausted config5) false
  shouldBe (rs3.isExhausted config5) false



end WorldmapTests.RetryLogicTests
