<#
    End-to-end smoke test against a running API. Creates fresh families each run,
    so it is safe to repeat against the same dev database.

    Usage (PowerShell 7):
        $env:ASPNETCORE_ENVIRONMENT = "Development"
        dotnet run --project backend/src/Family.Api --urls http://localhost:5080
        ./scripts/smoke-test.ps1 -BaseUrl http://localhost:5080

    Envelopes here are random bytes. The server must treat them as opaque, so
    they don't need to be real ciphertext to test the plumbing.
#>

param([string]$BaseUrl = "http://localhost:5080")

$ErrorActionPreference = "Stop"
$script:failures = 0

function Check([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else     { Write-Host "  FAIL  $name  $detail" -ForegroundColor Red; $script:failures++ }
}

function Call([string]$method, [string]$path, $body = $null, [string]$deviceId = $null) {
    $headers = @{}
    if ($deviceId) { $headers["X-Device-Id"] = $deviceId }
    $req = @{
        Method = $method; Uri = "$BaseUrl$path"; Headers = $headers
        SkipHttpErrorCheck = $true; ContentType = "application/json"
    }
    if ($null -ne $body) { $req.Body = ($body | ConvertTo-Json -Depth 10) }
    $r = Invoke-WebRequest @req
    [pscustomobject]@{
        Status = [int]$r.StatusCode
        Json   = if ($r.Content) { $r.Content | ConvertFrom-Json } else { $null }
    }
}

function RandomB64([int]$n = 32) {
    $b = [byte[]]::new($n); [Security.Cryptography.RandomNumberGenerator]::Fill($b)
    [Convert]::ToBase64String($b)
}

function NewFamily([string]$name) {
    (Call POST "/v1/families" @{
        name = $name; timeZone = "Europe/Stockholm"
        signingPublicKey = (RandomB64); kemPublicKey = (RandomB64)
        platform = "android"; founderProfileEnvelope = (RandomB64 64)
    }).Json
}

function Upsert([string]$objectId, [string]$envelope, $expectedVersion = $null) {
    @{
        clientCommandId = [guid]::NewGuid(); type = "object.upsert"
        targetObjectId = $objectId; targetKind = 1; scope = $null
        envelope = $envelope; expectedVersion = $expectedVersion
        # Local offset on purpose — the server must normalise it to UTC.
        issuedAt = [DateTimeOffset]::Now.ToOffset([TimeSpan]::FromHours(2)).ToString("o")
    }
}

Write-Host "`nSmoke test → $BaseUrl" -ForegroundColor Cyan

# --- health and auth ---------------------------------------------------------
Check "health" ((Call GET "/v1/health").Status -eq 200)
Check "sync without device header is 401" ((Call GET "/v1/sync").Status -eq 401)

# --- family and a second device ---------------------------------------------
$fam = NewFamily "Smoke A"
Check "create family" ($null -ne $fam.deviceId)
$devA = $fam.deviceId
$scope = "family:$($fam.familyId)"

$reg = Call POST "/v1/devices" @{
    familyId = $fam.familyId; memberId = $fam.memberId
    signingPublicKey = (RandomB64); kemPublicKey = (RandomB64); platform = "ios"
}
Check "register second device" ($reg.Status -eq 200)
$devB = $reg.Json.deviceId

$dir = Call GET "/v1/families/$($fam.familyId)/devices" -deviceId $devA
Check "key directory lists both devices" ($dir.Json.Count -eq 2)
Check "key directory needs a device" ((Call GET "/v1/families/$($fam.familyId)/devices").Status -eq 401)

# --- push from A, pull on B --------------------------------------------------
$obj1 = [guid]::NewGuid().ToString()
$env1 = RandomB64 128
$c1 = Upsert $obj1 $env1; $c1.scope = $scope
$r = Call POST "/v1/commands" @{ commands = @($c1) } $devA
Check "upsert applied (local-offset IssuedAt)" ($r.Status -eq 200 -and $r.Json.results[0].status -eq "applied") ($r | ConvertTo-Json -Depth 5 -Compress)

$s = Call GET "/v1/sync?since=0" -deviceId $devB
$got = $s.Json.changes | Where-Object id -eq $obj1
Check "device B pulls the object" ($null -ne $got)
Check "envelope round-trips byte-for-byte" ($got.envelope -eq $env1)
$cursor = $s.Json.cursor

# --- idempotency and conflicts ----------------------------------------------
$r = Call POST "/v1/commands" @{ commands = @($c1) } $devA
Check "replayed command is duplicate" ($r.Json.results[0].status -eq "duplicate")

$stale = Upsert $obj1 (RandomB64) 0; $stale.scope = $scope
$r = Call POST "/v1/commands" @{ commands = @($stale) } $devA
Check "stale ExpectedVersion is conflict" ($r.Json.results[0].status -eq "conflict")

$bad = Upsert ([guid]::NewGuid()) (RandomB64); $bad.type = "object.frobnicate"; $bad.scope = $scope
$r = Call POST "/v1/commands" @{ commands = @($bad) } $devA
Check "command outside allowlist is rejected" ($r.Json.results[0].status -eq "rejected")

# --- a failed insert must not poison the rest of the batch -------------------
# Family B owns an object id; family A then tries to write the same id (primary-key
# violation → DbUpdateException), followed by a valid command in the same batch.
$famB = NewFamily "Smoke B"
$objB = [guid]::NewGuid().ToString()
$cb = Upsert $objB (RandomB64); $cb.scope = "family:$($famB.familyId)"
Call POST "/v1/commands" @{ commands = @($cb) } $famB.deviceId | Out-Null

$collide = Upsert $objB (RandomB64); $collide.scope = $scope
$after = Upsert ([guid]::NewGuid()) (RandomB64); $after.scope = $scope
$after.issuedAt = [DateTimeOffset]::UtcNow.AddSeconds(5).ToString("o")   # ordered after the collision
$r = Call POST "/v1/commands" @{ commands = @($collide, $after) } $devA
$afterResult = $r.Json.results | Where-Object clientCommandId -eq $after.clientCommandId
Check "command after a failed insert still applies" ($afterResult.status -eq "applied") ($r.Json | ConvertTo-Json -Depth 5 -Compress)

$s = Call GET "/v1/sync?since=0" -deviceId $devA
Check "other family's object never syncs to A" (-not ($s.Json.changes | Where-Object id -eq $objB))

# --- delete ------------------------------------------------------------------
$del = Upsert $obj1 ""; $del.type = "object.delete"; $del.scope = $scope
Call POST "/v1/commands" @{ commands = @($del) } $devA | Out-Null
$s = Call GET "/v1/sync?since=$cursor" -deviceId $devB
$tomb = $s.Json.changes | Where-Object id -eq $obj1
Check "delete syncs as tombstone with no envelope" ($tomb.deleted -and $null -eq $tomb.envelope)

# --- wakes -------------------------------------------------------------------
$fire = [DateTimeOffset]::Now.AddHours(3).ToOffset([TimeSpan]::FromHours(2)).ToString("o")
$r = Call POST "/v1/wakes" @{ wakes = @(@{ correlationRef = "occ-1"; fireAt = $fire }); cancelRefs = @() } $devA
Check "wake scheduled (local-offset FireAt)" ($r.Status -eq 200 -and $r.Json.scheduled -eq 1) ($r | ConvertTo-Json -Compress)

$r = Call POST "/v1/wakes" @{ wakes = @(@{ correlationRef = "occ-1"; fireAt = $fire }); cancelRefs = @() } $devA
Check "same ref reschedules, not duplicates" ($r.Json.scheduled -eq 0)

$r = Call POST "/v1/wakes" @{ wakes = @(); cancelRefs = @("occ-1") } $devA
Check "wake cancelled" ($r.Json.cancelled -eq 1)

# --- wrapped keys ------------------------------------------------------------
$r = Call POST "/v1/keys" @{ groupName = "all"; epoch = 1; keys = @(@{ deviceId = $famB.deviceId; wrappedKey = (RandomB64) }) } $devA
Check "wrapping a key to another family's device is refused" ($r.Status -eq 400)

$wk = RandomB64
$r = Call POST "/v1/keys" @{ groupName = "all"; epoch = 1; keys = @(@{ deviceId = $devB; wrappedKey = $wk }) } $devA
Check "wrap key to own family's device" ($r.Status -eq 200)

$r = Call GET "/v1/keys" -deviceId $devB
Check "device B receives its wrapped key" (($r.Json | Where-Object { $_.groupName -eq "all" -and $_.epoch -eq 1 }).wrappedKey -eq $wk)

# --- pairing relay (crypto doc §7.1) ----------------------------------------
Check "another family's key directory is not found" ((Call GET "/v1/families/$($fam.familyId)/devices" -deviceId $famB.deviceId).Status -eq 404)
Check "push token needs a device" ((Call PUT "/v1/devices/push-token" @{ token = "t" }).Status -eq 401)

$adm = RandomB64 200
$r = Call POST "/v1/pairing/admissions" @{ toDeviceId = $devB; admission = $adm } $devA
Check "send admission to a family device" ($r.Status -eq 200)
$admissionId = $r.Json.admissionId

$r = Call POST "/v1/pairing/admissions" @{ toDeviceId = $famB.deviceId; admission = $adm } $devA
Check "admission to another family's device is refused" ($r.Status -eq 400)

$r = Call GET "/v1/pairing/admissions" -deviceId $devA
Check "the sender does not see the admission" (@($r.Json).Count -eq 0)

$r = Call GET "/v1/pairing/admissions" -deviceId $devB
$got = @($r.Json) | Where-Object admissionId -eq $admissionId
Check "recipient fetches the admission byte-for-byte" ($got.admission -eq $adm -and $got.fromDeviceId -eq $devA)

$r = Call DELETE "/v1/pairing/admissions/$admissionId" -deviceId $famB.deviceId
Check "another device cannot acknowledge it" ($r.Status -eq 404)
$r = Call DELETE "/v1/pairing/admissions/$admissionId" -deviceId $devB
Check "recipient acknowledges it" ($r.Status -eq 204)
$r = Call GET "/v1/pairing/admissions" -deviceId $devB
Check "acknowledged admission is gone" (@($r.Json).Count -eq 0)

$end1 = RandomB64 150
$r = Call POST "/v1/pairing/endorsements" @{ subjectDeviceId = $devB; endorsement = $end1 } $devA
Check "publish endorsement" ($r.Status -eq 204)
$end2 = RandomB64 150
Call POST "/v1/pairing/endorsements" @{ subjectDeviceId = $devB; endorsement = $end2 } $devA | Out-Null
$r = Call GET "/v1/pairing/endorsements" -deviceId $devB
$mine = @($r.Json) | Where-Object { $_.subjectDeviceId -eq $devB -and $_.endorserDeviceId -eq $devA }
Check "re-endorsing replaces, not duplicates" (@($mine).Count -eq 1 -and $mine.endorsement -eq $end2)
$r = Call GET "/v1/pairing/endorsements" -deviceId $famB.deviceId
Check "another family sees none of these endorsements" (-not (@($r.Json) | Where-Object subjectDeviceId -eq $devB))
$r = Call POST "/v1/pairing/endorsements" @{ subjectDeviceId = $famB.deviceId; endorsement = $end1 } $devA
Check "endorsing another family's device is refused" ($r.Status -eq 400)

# -----------------------------------------------------------------------------
if ($script:failures -eq 0) { Write-Host "`nAll checks passed." -ForegroundColor Green; exit 0 }
Write-Host "`n$($script:failures) check(s) failed." -ForegroundColor Red; exit 1
