<#
    End-to-end smoke test against a running API. Creates fresh families each run,
    so it is safe to repeat against the same dev database.

    Usage (PowerShell 7):
        $env:ASPNETCORE_ENVIRONMENT = "Development"
        dotnet run --project backend/src/Family.Api --urls http://localhost:5080
        ./scripts/smoke-test.ps1 -BaseUrl http://localhost:5080

    Envelopes here are random bytes. The server must treat them as opaque, so
    they don't need to be real ciphertext to test the plumbing. Device keys are
    real Ed25519 keys, because every request made as a device is signed with
    one (crypto doc §2.2); BouncyCastle comes from the API's own NuGet cache.
#>

param([string]$BaseUrl = "http://localhost:5080")

$ErrorActionPreference = "Stop"
$script:failures = 0

function Check([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else     { Write-Host "  FAIL  $name  $detail" -ForegroundColor Red; $script:failures++ }
}

$bc = Get-ChildItem "$HOME/.nuget/packages/bouncycastle.cryptography/*/lib/net6.0/BouncyCastle.Cryptography.dll" |
    Sort-Object FullName | Select-Object -Last 1
if (-not $bc) { throw "BouncyCastle not found: build backend/src/Family.Api once first" }
Add-Type -Path $bc.FullName
$Ed = [Org.BouncyCastle.Math.EC.Rfc8032.Ed25519]

# Signing seeds by device id: every device this script registers can sign.
$script:seeds = @{}

function RandomBytes([int]$n) {
    $b = [byte[]]::new($n); [Security.Cryptography.RandomNumberGenerator]::Fill($b); $b
}

function RandomB64([int]$n = 32) { [Convert]::ToBase64String((RandomBytes $n)) }

# A fresh Ed25519 key: the seed stays here, the public key goes to the server.
function NewKey {
    $seed = RandomBytes 32
    $public = [byte[]]::new(32)
    $Ed::GeneratePublicKey($seed, 0, $public, 0)
    [pscustomobject]@{ Seed = $seed; Public = [Convert]::ToBase64String($public) }
}

function Sign([byte[]]$seed, [string]$deviceId, [string]$method, [string]$target, [long]$ts, [byte[]]$body) {
    $digest = [Convert]::ToHexStringLower([Security.Cryptography.SHA256]::HashData($body))
    $message = [Text.Encoding]::UTF8.GetBytes("fam.req.v1`n$deviceId`n$method`n$target`n$ts`n$digest")
    $sig = [byte[]]::new(64)
    $Ed::Sign($seed, 0, $message, 0, $message.Length, $sig, 0)
    [Convert]::ToBase64String($sig)
}

# -Seed signs with another key, -Timestamp fakes a clock, -Unsigned sends the
# device header alone, -Headers replays exact headers.
function Call([string]$method, [string]$path, $body = $null, [string]$deviceId = $null,
              [byte[]]$Seed = $null, [long]$Timestamp = 0, [switch]$Unsigned, [hashtable]$Headers = $null) {
    $json = if ($null -ne $body) { $body | ConvertTo-Json -Depth 10 } else { "" }
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $h = @{}
    if ($Headers) { $h = $Headers }
    elseif ($deviceId) {
        $h["X-Device-Id"] = $deviceId
        if (-not $Unsigned) {
            $ts = if ($Timestamp) { $Timestamp } else { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
            $key = if ($Seed) { $Seed } else { $script:seeds[$deviceId] }
            $h["X-Fam-Timestamp"] = "$ts"
            $h["X-Fam-Signature"] = Sign $key $deviceId $method $path $ts $bytes
        }
    }
    $req = @{
        Method = $method; Uri = "$BaseUrl$path"; Headers = $h
        SkipHttpErrorCheck = $true; ContentType = "application/json"
    }
    if ($null -ne $body) { $req.Body = $bytes }
    $r = Invoke-WebRequest @req
    [pscustomobject]@{
        Status  = [int]$r.StatusCode
        Json    = if ($r.Content) { $r.Content | ConvertFrom-Json } else { $null }
        Headers = $h
    }
}

function NewFamily([string]$name) {
    $key = NewKey
    $fam = (Call POST "/v1/families" @{
        name = $name; timeZone = "Europe/Stockholm"
        signingPublicKey = $key.Public; kemPublicKey = (RandomB64)
        platform = "android"; founderProfileEnvelope = (RandomB64 64)
    }).Json
    $script:seeds[$fam.deviceId] = $key.Seed
    $fam
}

# Registers a device for $memberId as $asDevice; returns the response, and
# remembers the new device's key when it's created.
function RegisterDevice([string]$memberId, [string]$asDevice, [string]$platform = "android", $key = $null) {
    if (-not $key) { $key = NewKey }
    $r = Call POST "/v1/devices" @{ memberId = $memberId; signingPublicKey = $key.Public; kemPublicKey = (RandomB64); platform = $platform } $asDevice
    if ($r.Status -eq 200) { $script:seeds[$r.Json.deviceId] = $key.Seed }
    $r
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

# A parent's device registers new devices (crypto doc §7.1); nothing registers anonymously.
$keyB = NewKey
Check "anonymous device registration is refused" ((Call POST "/v1/devices" @{ memberId = $fam.memberId; signingPublicKey = $keyB.Public; kemPublicKey = (RandomB64); platform = "ios" }).Status -eq 401)
$reg = RegisterDevice $fam.memberId $devA "ios" $keyB
Check "a parent's device registers a second device" ($reg.Status -eq 200)
$devB = $reg.Json.deviceId
Check "the same keys can't register twice" ((RegisterDevice $fam.memberId $devA "ios" $keyB).Status -eq 409)

# --- request signatures (crypto doc §2.2) ---------------------------------------
Check "a signed request is accepted" ((Call GET "/v1/keys" -deviceId $devA).Status -eq 200)
Check "the device id alone is refused" ((Call GET "/v1/keys" -deviceId $devA -Unsigned).Status -eq 401)
Check "another key's signature is refused" ((Call GET "/v1/keys" -deviceId $devA -Seed (NewKey).Seed).Status -eq 401)
$stale = [DateTimeOffset]::UtcNow.AddMinutes(-10).ToUnixTimeMilliseconds()
$r = Call GET "/v1/keys" -deviceId $devA -Timestamp $stale
Check "a ten-minute-old signature is refused as clock skew" ($r.Status -eq 401 -and $r.Json.error -eq "clock_skew")
$first = Call GET "/v1/keys" -deviceId $devB
$again = Call GET "/v1/keys" -Headers $first.Headers
Check "an exact replay is refused" ($first.Status -eq 200 -and $again.Status -eq 401 -and $again.Json.error -eq "replayed")
$signed = Call PUT "/v1/devices/push-token" @{ token = "a" } $devB
$h = @{ "X-Device-Id" = $devB; "X-Fam-Timestamp" = "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())" }
$h["X-Fam-Signature"] = Sign $script:seeds[$devB] $devB "PUT" "/v1/devices/push-token" ([long]$h["X-Fam-Timestamp"]) ([Text.Encoding]::UTF8.GetBytes('{"token":"a"}'))
$swapped = Invoke-WebRequest -Method PUT -Uri "$BaseUrl/v1/devices/push-token" -Headers $h -Body '{"token":"b"}' -ContentType "application/json" -SkipHttpErrorCheck
Check "a changed body breaks the signature" ($signed.Status -eq 204 -and [int]$swapped.StatusCode -eq 401)

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

# A change wakes the family's other devices, once, and never the author.
Call PUT "/v1/devices/push-token" @{ token = "tok-$([guid]::NewGuid())" } $devB | Out-Null
$c2 = Upsert ([guid]::NewGuid().ToString()) (RandomB64); $c2.scope = $scope
Call POST "/v1/commands" @{ commands = @($c2) } $devA | Out-Null
$c3 = Upsert ([guid]::NewGuid().ToString()) (RandomB64); $c3.scope = $scope
Call POST "/v1/commands" @{ commands = @($c3) } $devA | Out-Null
$r = Call POST "/v1/wakes" @{ wakes = @(); cancelRefs = @("sync") } $devB
Check "two quick changes leave one wake for the other device" ($r.Json.cancelled -eq 1) ($r | ConvertTo-Json -Compress)
$r = Call POST "/v1/wakes" @{ wakes = @(); cancelRefs = @("sync") } $devA
Check "the author gets no change wake" ($r.Json.cancelled -eq 0)

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

# --- members and child devices ----------------------------------------------
$r = Call POST "/v1/members" @{ role = 1; profileEnvelope = (RandomB64 64) } $devA
Check "a parent adds a child member" ($r.Status -eq 200)
$child = $r.Json.memberId
$r = RegisterDevice $child $devA
Check "a parent registers the child's tablet" ($r.Status -eq 200)
$tablet = $r.Json.deviceId
$r = RegisterDevice $child $tablet
Check "a child's device cannot register devices" ($r.Status -eq 403)
Check "a child's device cannot add members" ((Call POST "/v1/members" @{ role = 1; profileEnvelope = (RandomB64) } $tablet).Status -eq 403)
$r = RegisterDevice $famB.memberId $devA "ios"
Check "registering a device to another family's member is not found" ($r.Status -eq 404)

# --- pairing relay (crypto doc §7.1) ----------------------------------------
Check "another family's key directory is not found" ((Call GET "/v1/families/$($fam.familyId)/devices" -deviceId $famB.deviceId).Status -eq 404)
Check "push token needs a device" ((Call PUT "/v1/devices/push-token" @{ token = "t" }).Status -eq 401)
$token = "tok-$([guid]::NewGuid())"
Call PUT "/v1/devices/push-token" @{ token = $token } $devA | Out-Null
Check "a push token moves to another device" ((Call PUT "/v1/devices/push-token" @{ token = $token } $devB).Status -eq 204)

$adm = RandomB64 200
$mailbox = -join ((1..32) | ForEach-Object { '0123456789abcdef'[(Get-Random -Maximum 16)] })
$r = Call POST "/v1/pairing/admissions" @{ toDeviceId = $devB; mailbox = $mailbox; admission = $adm } $devA
Check "leave an admission at a mailbox" ($r.Status -eq 200)
$admissionId = $r.Json.admissionId

$r = Call POST "/v1/pairing/admissions" @{ toDeviceId = $devB; mailbox = "NOT-A-MAILBOX"; admission = $adm } $devA
Check "a malformed mailbox is refused" ($r.Status -eq 400)
$r = Call POST "/v1/pairing/admissions" @{ toDeviceId = $famB.deviceId; mailbox = $mailbox; admission = $adm } $devA
Check "admission to another family's device is refused" ($r.Status -eq 400)

# The new device can't authenticate yet, so it collects anonymously.
$r = Call GET "/v1/pairing/mailbox/$mailbox"
$got = @($r.Json) | Where-Object admissionId -eq $admissionId
Check "the mailbox yields the admission byte-for-byte, anonymously" ($got.admission -eq $adm -and $got.fromDeviceId -eq $devA)
$other = -join ((1..32) | ForEach-Object { '0123456789abcdef'[(Get-Random -Maximum 16)] })
Check "another mailbox is empty" (@((Call GET "/v1/pairing/mailbox/$other").Json).Count -eq 0)
Check "a malformed mailbox address is not found" ((Call GET "/v1/pairing/mailbox/zz").Status -eq 404)
Check "mailbox paths don't open other routes" ((Call GET "/v1/pairing/mailbox/$mailbox/x").Status -eq 401)

$r = Call DELETE "/v1/pairing/admissions/$admissionId" -deviceId $famB.deviceId
Check "another device cannot acknowledge it" ($r.Status -eq 404)
$r = Call DELETE "/v1/pairing/admissions/$admissionId" -deviceId $devB
Check "recipient acknowledges it" ($r.Status -eq 204)
$r = Call GET "/v1/pairing/mailbox/$mailbox"
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
