namespace Family.Api.Domain;

/// <summary>
/// The server stores ciphertext it cannot read. Every "object" below is an opaque
/// envelope plus the minimum metadata needed to route, order and schedule it.
/// See the crypto design document for the envelope format.
/// </summary>

public class FamilyGroup
{
    public Guid Id { get; set; }

    /// <summary>
    /// Plaintext by decision — listed in the architecture doc's "What the server can
    /// still see". The one named field outside an envelope; don't add another.
    /// </summary>
    public string Name { get; set; } = "";

    public string TimeZone { get; set; } = "Europe/Stockholm";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public List<Member> Members { get; set; } = new();
}

public enum MemberRole { Parent, Child, Helper }

public class Member
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public MemberRole Role { get; set; }

    /// <summary>Display name is content, so it is encrypted like everything else.</summary>
    public byte[] ProfileEnvelope { get; set; } = Array.Empty<byte>();

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? EndedAt { get; set; }

    public List<Device> Devices { get; set; } = new();
}

public class Device
{
    public Guid Id { get; set; }
    public Guid MemberId { get; set; }
    public Guid FamilyId { get; set; }

    /// <summary>Ed25519 public key, base64. Used to verify the device's signatures.</summary>
    public string SigningPublicKey { get; set; } = "";

    /// <summary>X25519 public key, base64. Used to wrap group keys to this device.</summary>
    public string KemPublicKey { get; set; } = "";

    public string Platform { get; set; } = "";
    public string? PushToken { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? RevokedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// A group content key wrapped to one device, for one epoch. The server relays
/// these blobs between devices and cannot unwrap any of them.
/// </summary>
public class WrappedGroupKey
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public string GroupName { get; set; } = "";
    public long Epoch { get; set; }
    public Guid DeviceId { get; set; }
    public byte[] WrappedKey { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// Pairing admission (crypto doc §7.1): tells a newly scanned device which family
/// devices to trust. Authenticated by a key only the scanner holds, so the server
/// can relay it but not forge or alter it. Collected from a mailbox before the
/// recipient can authenticate; deleted once it acknowledges as itself.
/// </summary>
public class PairingAdmission
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid ToDeviceId { get; set; }
    public Guid FromDeviceId { get; set; }

    /// <summary>
    /// Where the new device collects it before it can authenticate: derived from
    /// the pairing code's secret, which the server never sees (crypto doc §7.1).
    /// </summary>
    public string Mailbox { get; set; } = "";

    public byte[] Admission { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// A device's keys vouched for by another family device (crypto doc §7.1), so the
/// rest of the family trusts them without taking the key directory's word.
/// Signed by the endorser; opaque here.
/// </summary>
public class DeviceEndorsement
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid SubjectDeviceId { get; set; }
    public Guid EndorserDeviceId { get; set; }
    public byte[] Endorsement { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public enum ObjectKind
{
    Event = 1,
    Place = 2,
    Action = 3,
    Person = 4,
    MealPlanEntry = 5,
    Recipe = 6,
    ShoppingList = 7,
    ShoppingListItem = 8,
    Homework = 9,
    Wishlist = 10,
    WishlistItem = 11,
    EquipmentSet = 12,
    Settings = 13,

    /// <summary>
    /// A member's name, colour and the like, keyed by the member's id. Content, so
    /// it syncs as an envelope; Member.ProfileEnvelope predates this and stays empty.
    /// Append-only: never renumber or reuse a value.
    /// </summary>
    MemberProfile = 14,

    /// <summary>
    /// One occurrence of a recurring event cancelled, moved or changed (spec §3
    /// event_exception). Its own object, so a one-week change never rewrites the
    /// series; which event it belongs to is inside the envelope.
    /// </summary>
    EventException = 15
}

/// <summary>
/// The single table every synced object lives in. The server sees the kind, the
/// scope it belongs to, and a version — never the content.
///
/// Scope is one of: "family:{id}", "member:{id}", "child:{personId}".
/// It decides which devices receive the row, and nothing more.
/// </summary>
public class SyncObject
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public ObjectKind Kind { get; set; }
    public string Scope { get; set; } = "";

    public byte[] Envelope { get; set; } = Array.Empty<byte>();

    /// <summary>Server-assigned, monotonic per family. The delta sync cursor.</summary>
    public long Sequence { get; set; }

    public long Version { get; set; }
    public bool Deleted { get; set; }
    public Guid? DeletedByDeviceId { get; set; }

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public Guid UpdatedByDeviceId { get; set; }
}

/// <summary>
/// A command issued by a device, possibly while offline. Idempotent on
/// (DeviceId, ClientCommandId) so replays are free.
/// </summary>
public class CommandRecord
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid DeviceId { get; set; }
    public Guid ClientCommandId { get; set; }
    public string Type { get; set; } = "";

    /// <summary>Encrypted command payload. The server applies it structurally, not semantically.</summary>
    public byte[] Envelope { get; set; } = Array.Empty<byte>();

    public Guid TargetObjectId { get; set; }
    public DateTimeOffset IssuedAt { get; set; }
    public DateTimeOffset ReceivedAt { get; set; } = DateTimeOffset.UtcNow;
    public long ResultingSequence { get; set; }
}

/// <summary>
/// A contentless reminder. The server knows only which device to wake and when;
/// the device decrypts locally and builds the notification text itself.
/// </summary>
public class ScheduledWake
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid DeviceId { get; set; }

    /// <summary>Opaque to the server. The device uses it to find the right local object.</summary>
    public string CorrelationRef { get; set; } = "";

    public DateTimeOffset FireAt { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    public string State { get; set; } = "scheduled";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
