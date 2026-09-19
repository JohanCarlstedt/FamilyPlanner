using Family.Api.Domain;

namespace Family.Api.Contracts;

// ---- families and devices -------------------------------------------------

public record CreateFamilyRequest(
    string Name,
    string TimeZone,
    string SigningPublicKey,
    string KemPublicKey,
    string Platform,
    byte[] FounderProfileEnvelope);

public record CreateFamilyResponse(Guid FamilyId, Guid MemberId, Guid DeviceId);

public record RegisterDeviceRequest(
    Guid MemberId,
    string SigningPublicKey,
    string KemPublicKey,
    string Platform);

public record RegisterDeviceResponse(Guid DeviceId);

public record CreateMemberRequest(MemberRole Role, byte[] ProfileEnvelope);

public record CreateMemberResponse(Guid MemberId);

public record DeviceKeyDto(
    Guid DeviceId,
    Guid MemberId,
    string SigningPublicKey,
    string KemPublicKey,
    bool Revoked,
    string Platform);

public record PublishWrappedKeysRequest(string GroupName, long Epoch, List<WrappedKeyDto> Keys);

public record WrappedKeyDto(Guid DeviceId, byte[] WrappedKey);

public record PushTokenRequest(string Token);

// ---- pairing (crypto doc §7.1) ---------------------------------------------

public record SendAdmissionRequest(Guid ToDeviceId, string Mailbox, byte[] Admission);

public record SendAdmissionResponse(Guid AdmissionId);

public record AdmissionDto(Guid AdmissionId, Guid FromDeviceId, byte[] Admission, DateTimeOffset CreatedAt);

public record PublishEndorsementRequest(Guid SubjectDeviceId, byte[] Endorsement);

public record EndorsementDto(Guid SubjectDeviceId, Guid EndorserDeviceId, byte[] Endorsement, DateTimeOffset CreatedAt);

// ---- sync -----------------------------------------------------------------

public record SyncObjectDto(
    Guid Id,
    ObjectKind Kind,
    string Scope,
    byte[]? Envelope,
    long Version,
    bool Deleted,
    DateTimeOffset UpdatedAt);

public record SyncResponse(List<SyncObjectDto> Changes, long Cursor, bool HasMore);

// ---- commands -------------------------------------------------------------

/// <summary>
/// Offline writes arrive as commands, not row state. Idempotent on ClientCommandId.
/// Type is one of a deliberately small allowlist — see CommandEndpoints.
/// </summary>
public record CommandDto(
    Guid ClientCommandId,
    string Type,
    Guid TargetObjectId,
    ObjectKind TargetKind,
    string Scope,
    byte[] Envelope,
    long? ExpectedVersion,
    DateTimeOffset IssuedAt);

public record SubmitCommandsRequest(List<CommandDto> Commands);

public record CommandResultDto(Guid ClientCommandId, string Status, long? Sequence, string? Reason);

public record SubmitCommandsResponse(List<CommandResultDto> Results, long Cursor);

// ---- scheduling -----------------------------------------------------------

public record ScheduleWakeDto(string CorrelationRef, DateTimeOffset FireAt);

public record RegisterWakesRequest(List<ScheduleWakeDto> Wakes, List<string> CancelRefs);

public record RegisterWakesResponse(int Scheduled, int Cancelled);
