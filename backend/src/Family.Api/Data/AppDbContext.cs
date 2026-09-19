using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<FamilyGroup> Families => Set<FamilyGroup>();
    public DbSet<Member> Members => Set<Member>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<WrappedGroupKey> WrappedGroupKeys => Set<WrappedGroupKey>();
    public DbSet<SyncObject> SyncObjects => Set<SyncObject>();
    public DbSet<CommandRecord> Commands => Set<CommandRecord>();
    public DbSet<ScheduledWake> ScheduledWakes => Set<ScheduledWake>();
    public DbSet<PairingAdmission> PairingAdmissions => Set<PairingAdmission>();
    public DbSet<DeviceEndorsement> DeviceEndorsements => Set<DeviceEndorsement>();
    public DbSet<MlsKeyPackage> MlsKeyPackages => Set<MlsKeyPackage>();
    public DbSet<MlsGroupState> MlsGroups => Set<MlsGroupState>();
    public DbSet<MlsMessage> MlsMessages => Set<MlsMessage>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // One sequence per database is simpler than per family and just as ordered.
        // Clients treat the cursor as opaque.
        b.HasSequence<long>("sync_sequence").StartsAt(1).IncrementsBy(1);

        b.Entity<MlsKeyPackage>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.DeviceId, x.ClaimedAt });
        });

        b.Entity<MlsGroupState>(e => e.HasKey(x => x.GroupId));

        b.Entity<MlsMessage>(e =>
        {
            e.HasKey(x => x.Seq);
            e.Property(x => x.Seq).UseIdentityAlwaysColumn();
            e.HasIndex(x => new { x.FamilyId, x.Seq });
        });

        b.Entity<FamilyGroup>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasMany(x => x.Members).WithOne().HasForeignKey(m => m.FamilyId);
        });

        b.Entity<Member>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => x.FamilyId);
            e.HasMany(x => x.Devices).WithOne().HasForeignKey(d => d.MemberId);
        });

        b.Entity<Device>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.FamilyId, x.RevokedAt });
            e.HasIndex(x => x.SigningPublicKey).IsUnique();
        });

        b.Entity<WrappedGroupKey>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.DeviceId, x.GroupName, x.Epoch }).IsUnique();
            e.HasIndex(x => new { x.FamilyId, x.GroupName, x.Epoch });
        });

        b.Entity<SyncObject>(e =>
        {
            e.HasKey(x => x.Id);
            // The delta query: everything in my scopes after my cursor.
            e.HasIndex(x => new { x.FamilyId, x.Sequence });
            e.HasIndex(x => new { x.FamilyId, x.Scope, x.Sequence });
            e.Property(x => x.Sequence).HasDefaultValueSql("nextval('sync_sequence')");
        });

        b.Entity<CommandRecord>(e =>
        {
            e.HasKey(x => x.Id);
            // Idempotency: a replayed command is recognised, not reapplied.
            e.HasIndex(x => new { x.DeviceId, x.ClientCommandId }).IsUnique();
            e.HasIndex(x => x.FamilyId);
        });

        b.Entity<ScheduledWake>(e =>
        {
            e.HasKey(x => x.Id);
            // The sender's claim query.
            e.HasIndex(x => new { x.State, x.FireAt });
            e.HasIndex(x => new { x.DeviceId, x.CorrelationRef });
        });

        b.Entity<PairingAdmission>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.ToDeviceId, x.CreatedAt });
            e.HasIndex(x => x.Mailbox);
            e.Property(x => x.Mailbox).HasMaxLength(32);
        });

        b.Entity<DeviceEndorsement>(e =>
        {
            e.HasKey(x => x.Id);
            // One endorsement per endorser for each device; re-endorsing replaces it.
            e.HasIndex(x => new { x.SubjectDeviceId, x.EndorserDeviceId }).IsUnique();
            e.HasIndex(x => x.FamilyId);
        });
    }
}
