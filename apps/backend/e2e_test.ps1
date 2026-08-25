
# JUGAAD E2E TEST - Full Job Lifecycle
$GW      = "https://jugaad-gateway-9ilmeeco.uc.gateway.dev"
$TOKEN   = (gcloud auth print-identity-token 2>&1)
$USER_ID   = "test-user-001"
$WORKER_ID = "test-worker-001"
$JOB_ID    = $null

function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " STEP $n : $msg" -ForegroundColor Cyan
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
}
function Write-OK($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-FAIL($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; exit 1 }
function Write-INFO($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Yellow }

function Call-API($method, $path, $body) {
    $url = "$GW$path"
    $headers = @{
        "Authorization" = "Bearer $TOKEN"
        "Content-Type" = "application/json"
    }
    try {
        if ($body) {
            $resp = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 30
        } else {
            $resp = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -UseBasicParsing -TimeoutSec 30
        }
        $code = [int]$resp.StatusCode
        $content = $resp.Content
    } catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
        } else {
            $code = "500"
            $content = $_.Exception.Message
        }
    }
    return @{ code = "$code"; body = $content }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Magenta
Write-Host "   JUGAAD END-TO-END TEST SUITE" -ForegroundColor Magenta
Write-Host "   User   : $USER_ID" -ForegroundColor Magenta
Write-Host "   Worker : $WORKER_ID" -ForegroundColor Magenta
Write-Host "===============================================" -ForegroundColor Magenta

# STEP 1: Create Job Request
Write-Step 1 "Create Job Request (POST /v1/jobs)"
$jobBody = '{"user_id":"test-user-001","skill":"plumber","description":"Leaking pipe in kitchen","lat":12.3052,"lng":76.6552,"address":"123 MG Road, Mysuru","budget_min":300,"budget_max":800,"is_urgent":true}'
$r = Call-API "POST" "/v1/jobs" $jobBody
Write-INFO "HTTP $($r.code)"
Write-INFO "$($r.body)"
if ($r.code -ne "200") { Write-FAIL "Job creation failed" }

try {
    $resp = $r.body | ConvertFrom-Json
    $JOB_ID = $resp.job_id
} catch {
    Write-FAIL "Could not parse job_id from: $($r.body)"
}
if (-not $JOB_ID) { Write-FAIL "No job_id in response" }
Write-OK "Job created: $JOB_ID"

# STEP 2: Wait for Pub/Sub Matching
Write-Step 2 "Waiting 6s for Pub/Sub to push JOB_BROADCASTED to matching-service"
Write-INFO "Pub/Sub push: jugaad-job-events -> matching-service /pubsub-push"
Start-Sleep -Seconds 6

# STEP 3: Verify Matching
Write-Step 3 "Verify Job Matched (GET /v1/jobs/$JOB_ID)"
$r = Call-API "GET" "/v1/jobs/$JOB_ID" $null
Write-INFO "HTTP $($r.code)"
if ($r.code -ne "200") { Write-FAIL "Get job failed" }
try {
    $job = $r.body | ConvertFrom-Json
    Write-INFO "status      : $($job.status)"
    Write-INFO "match_count : $($job.match_count)"
    if ($job.match_count -gt 0) {
        Write-OK "Matching SUCCESS - $($job.match_count) worker(s) found nearby"
    } else {
        Write-INFO "No workers matched yet (Pub/Sub may still propagate). Continuing..."
    }
} catch {
    Write-INFO "Could not parse job JSON, continuing..."
}

# STEP 4: Worker Accepts Job
Write-Step 4 "Worker Accepts Job (POST /v1/jobs/$JOB_ID/accept)"
$acceptBody = "{`"worker_id`":`"$WORKER_ID`"}"
$r = Call-API "POST" "/v1/jobs/$JOB_ID/accept" $acceptBody
Write-INFO "HTTP $($r.code) | $($r.body)"
if ($r.code -ne "200") { Write-FAIL "Accept failed" }
Write-OK "Worker $WORKER_ID accepted job"
Start-Sleep -Seconds 2

# STEP 5: Worker Acknowledges (Arrived at location)
Write-Step 5 "Worker Acknowledges Arrival (POST /v1/jobs/$JOB_ID/ack)"
$ackBody = "{`"worker_id`":`"$WORKER_ID`"}"
$r = Call-API "POST" "/v1/jobs/$JOB_ID/ack" $ackBody
Write-INFO "HTTP $($r.code) | $($r.body)"
if ($r.code -ne "200") { Write-FAIL "Ack failed" }
Write-OK "Worker arrived and acknowledged"
Start-Sleep -Seconds 2

# STEP 6: Worker Completes Job
Write-Step 6 "Worker Completes Job (POST /v1/jobs/$JOB_ID/complete)"
$completeBody = "{`"worker_id`":`"$WORKER_ID`",`"payment_amount`":500,`"notes`":`"Fixed the pipe`"}"
$r = Call-API "POST" "/v1/jobs/$JOB_ID/complete" $completeBody
Write-INFO "HTTP $($r.code) | $($r.body)"
if ($r.code -ne "200") { Write-FAIL "Complete failed" }
Write-OK "Job marked COMPLETED"
Start-Sleep -Seconds 2

# STEP 7: Verify Final State
Write-Step 7 "Verify Final Job State (GET /v1/jobs/$JOB_ID)"
$r = Call-API "GET" "/v1/jobs/$JOB_ID" $null
if ($r.code -ne "200") { Write-FAIL "Final state check failed" }
try {
    $final = $r.body | ConvertFrom-Json
    Write-Host ""
    Write-Host "  +----- FINAL JOB SUMMARY ---------------" -ForegroundColor Cyan
    Write-Host "  | job_id         : $JOB_ID"
    Write-Host "  | status         : $($final.status)"
    Write-Host "  | worker_id      : $($final.worker_id)"
    Write-Host "  | payment_amount : Rs.$($final.payment_amount)"
    Write-Host "  +----------------------------------------" -ForegroundColor Cyan
} catch {
    Write-INFO "Final: $($r.body)"
}

# STEP 8: Create Payment Order
Write-Step 8 "Create Payment Order (POST /v1/jobs/$JOB_ID/create-order)"
$r = Call-API "POST" "/v1/jobs/$JOB_ID/create-order" "{}"
Write-INFO "HTTP $($r.code) | $($r.body)"
if ($r.code -eq "200") {
    Write-OK "Razorpay order created"
} else {
    Write-INFO "Payment HTTP $($r.code) - expected with test Razorpay keys"
}

# STEP 9: Submit Review
Write-Step 9 "Customer Reviews Worker (POST /v1/jobs/$JOB_ID/review)"
$reviewBody = "{`"rating`":5,`"comment`":`"Excellent work!`",`"user_id`":`"$USER_ID`"}"
$r = Call-API "POST" "/v1/jobs/$JOB_ID/review" $reviewBody
Write-INFO "HTTP $($r.code) | $($r.body)"
if ($r.code -eq "200") {
    Write-OK "5-star review submitted"
} else {
    Write-INFO "Review HTTP $($r.code)"
}

# FINAL SUMMARY
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "   E2E TEST COMPLETE" -ForegroundColor Green
Write-Host "   Job ID : $JOB_ID" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Firestore audit trail:" -ForegroundColor DarkGray
$url = "https://console.firebase.google.com/project/jugaad-prod-app-2026/firestore/data/jobs/" + $JOB_ID
Write-Host "  $url" -ForegroundColor DarkCyan
