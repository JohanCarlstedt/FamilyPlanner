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
    EventException = 15,

    /// <summary>
    /// A helper's access: who, which children, until when. Content, sealed to
    /// the parents; the server sees only that one exists.
    /// </summary>
    HelperGrant = 16,

    /// <summary>
    /// A calendar feed linked to a member (an integration): content, sealed to
    /// the parents. Parents' devices fetch it; the server never learns which
    /// feed.
    /// </summary>
    CalendarLink = 17,

    /// <summary>A meal someone suggested (spec §4 `meal_suggestion`).</summary>
    MealSuggestion = 18,

    /// <summary>A meal poll and its options (spec §4 `meal_poll`).</summary>
    MealPoll = 19,

    /// <summary>One member's ticks in one poll (spec §4 `meal_vote`).</summary>
    MealVote = 20,

    /// <summary>
    /// Recurring prep on an event, or a chore on its own schedule (spec §3
    /// `action_template`); devices plan `Action` objects from it.
    /// </summary>
    ActionTemplate = 21,

    /// <summary>
    /// Someone saying they'll buy a wishlist item (spec §3 `wishlist_claim`);
    /// apart from the item, so the list's owner never gets it.
    /// </summary>
    WishlistClaim = 22,

    /// <summary>A child's school subject (spec §3 `subject`).</summary>
    Subject = 23,

    /// <summary>Away mode or a school break (spec §3 `absence`).</summary>
    Absence = 24,

    /// <summary>"Can I…?" from a child to the parents (spec §3 `approval_request`).</summary>
    ApprovalRequest = 25,

    /// <summary>Where a child of two homes is when (spec §3 `custody_arrangement`).</summary>
    CustodyArrangement = 26,

    /// <summary>
    /// Who a member shares their position with, and how precisely (spec §7
    /// `location_share_setting`). Positions themselves travel over MLS.
    /// </summary>
    LocationShare = 27,

    /// <summary>
    /// A password the family keeps (the wifi, a streaming account) or one
    /// member's own. Content, sealed to whoever it is for; the server sees
    /// only that one exists.
    /// </summary>
    Credential = 28,

    /// <summary>
    /// Homework that comes back every week. It plans an ordinary Homework
    /// object per week, each done or not on its own.
    /// </summary>
    HomeworkTemplate = 29,

    /// <summary>
    /// A school's week overview, kept so the family can look at each new
    /// week's without finding the link again.
    /// </summary>
    WeekPlanLink = 30
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

/// <summary>
/// An MLS key package a device published so others can add it to a chat group
/// (crypto doc §7.2). Opaque; each is handed out once.
/// </summary>
public class MlsKeyPackage
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid DeviceId { get; set; }
    public byte[] KeyPackage { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? ClaimedAt { get; set; }
}

/// <summary>An MLS group's position: the delivery service orders commits by it.</summary>
public class MlsGroupState
{
    /// <summary>The MLS group id, hex.</summary>
    public string GroupId { get; set; } = "";
    public Guid FamilyId { get; set; }
    public long Epoch { get; set; }
}

/// <summary>
/// One message relayed for an MLS group: a commit, an application message, or
/// a welcome for one device. Opaque; ordered by <see cref="Seq"/>.
/// </summary>
public class MlsMessage
{
    public long Seq { get; set; }
    public Guid FamilyId { get; set; }
    public string GroupId { get; set; } = "";
    public long Epoch { get; set; }

    /// <summary><c>commit</c>, <c>application</c> or <c>welcome</c>.</summary>
    public string Kind { get; set; } = "";
    public Guid SenderDeviceId { get; set; }

    /// <summary>For a welcome: the only device that may fetch it.</summary>
    public Guid? RecipientDeviceId { get; set; }

    /// <summary>
    /// For an application message that replaces its sender's last one in the
    /// same slot, e.g. <c>position</c> (spec §7: latest only, no trail, not
    /// even of ciphertext).
    /// </summary>
    public string? Slot { get; set; }
    public byte[] Body { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// A member's recovery kit (crypto doc §7.3): which device the twelve words act
/// as, and a note only the words open. Looked up by an id derived from the
/// words, so the lookup needs no account.
/// </summary>
public class RecoveryKit
{
    /// <summary>16 bytes derived from the words, hex.</summary>
    public string LookupId { get; set; } = "";
    public Guid FamilyId { get; set; }
    public Guid MemberId { get; set; }
    public Guid DeviceId { get; set; }
    public byte[] Note { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// An encrypted photo or file (spec §3 "Attachments"): an envelope the server
/// can't open, sealed on the phone like the object it belongs to. What it is
/// and what it's attached to live inside that object, not here.
/// </summary>
public class Blob
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid UploadedByDeviceId { get; set; }
    public int Size { get; set; }
    public byte[] Bytes { get; set; } = Array.Empty<byte>();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// Whether a family has premium, and until when (docs/going-public.md).
///
/// Plaintext by decision, and the reasoning is worth keeping: a subscription is
/// metadata, not content. The server already knows which families exist and
/// when their devices sync, so knowing that one has paid tells it nothing it
/// could not already see. Invariant 1 is untouched — no readable family content
/// appears here.
///
/// One row per family, and the only row the family itself never writes: it is
/// changed by the store's notifications and by grants, never by a device.
/// </summary>
public class Subscription
{
    public Guid FamilyId { get; set; }

    /// <summary>
    /// What the billing provider knows this family as, and all it knows.
    ///
    /// Random and separate from <see cref="FamilyId"/> on purpose: the family
    /// id appears throughout our own API, and there is no reason for a third
    /// party's records to be joinable to ours if either is ever spilled. The
    /// app registers with the provider under this and nothing else.
    /// </summary>
    public Guid BillingId { get; set; }

    /// <summary>
    /// When premium runs out; null if this family has never had it. Includes
    /// whatever grace the store granted — a card that failed is still premium
    /// while the store retries it, and that is the store's call, not ours.
    /// </summary>
    public DateTimeOffset? PremiumUntil { get; set; }

    /// <summary>Where it came from, for support questions and nothing else.</summary>
    public SubscriptionSource Source { get; set; } = SubscriptionSource.None;

    /// <summary>The store's product identifier, when a store sold it.</summary>
    public string? ProductId { get; set; }

    /// <summary>
    /// The timestamp of the last event applied. Notifications arrive out of
    /// order often enough to matter — a renewal overtaking the billing-issue
    /// notice that preceded it would otherwise expire a family that has paid.
    /// </summary>
    public DateTimeOffset? LastEventAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>
    /// A grant with no end. Stored as a date rather than a flag so that every
    /// question about premium is the same comparison, with no second rule to
    /// forget somewhere.
    /// </summary>
    public static readonly DateTimeOffset Forever =
        new(9999, 12, 31, 23, 59, 59, TimeSpan.Zero);

    public bool IsPremiumAt(DateTimeOffset now) => PremiumUntil > now;
}

public enum SubscriptionSource
{
    None = 0,
    AppStore = 1,
    PlayStore = 2,

    /// <summary>
    /// Given rather than sold: friends, families who were here before there
    /// was a price, someone owed an apology. No money and no store involved.
    /// </summary>
    Granted = 3
}
