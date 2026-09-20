using System.Threading.RateLimiting;

namespace Family.Api.Auth;

/// <summary>
/// What one address may ask of the server. The signature check already
/// refuses an unknown device, but it refuses it after a database lookup, and
/// nothing stopped anyone doing that a few thousand times a second. These are
/// the limits that make the endpoint boring to attack.
/// </summary>
/// <remarks>
/// Partitioned by address, not by device id: a device id is a header anyone
/// can invent, so partitioning by it would let a flood give itself a fresh
/// bucket per request. A household behind one address shares its partition,
/// which is why the general limit is generous.
/// </remarks>
public static class RateLimiting
{
    /// <summary>Anyone can create a family; nobody needs to create many.</summary>
    public const string CreateFamily = "create-family";

    /// <summary>
    /// The two anonymous lookups: a pairing mailbox and a recovery kit. Both
    /// answer on an id alone, so both are worth guessing at — slowly.
    /// </summary>
    public const string Lookup = "lookup";

    /// <summary>
    /// A busy phone syncs twice a minute, and a few more while someone is
    /// watching the map. This is room for a houseful of them and their
    /// mistakes, and still far below what hurts.
    /// </summary>
    public const int RequestsPerMinute = 600;

    public const int FamiliesPerHour = 5;
    public const int LookupsPerMinute = 30;

    /// <summary>
    /// The address a request came from. Behind the reverse proxy this is what
    /// UseForwardedHeaders has already resolved; if the API is ever published
    /// directly, that header becomes a thing anyone can set and this becomes
    /// a partition anyone can choose.
    /// </summary>
    public static string ClientKey(HttpContext http) =>
        http.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    public static IServiceCollection AddFamilyRateLimits(this IServiceCollection services) =>
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            // A refusal says when to come back: a phone that is merely
            // enthusiastic should back off rather than retry in a loop.
            options.OnRejected = async (context, token) =>
            {
                var seconds = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var after)
                    ? (int)after.TotalSeconds
                    : 60;
                context.HttpContext.Response.Headers.RetryAfter = seconds.ToString();
                await context.HttpContext.Response.WriteAsJsonAsync(
                    new { error = "rate_limited", retryAfterSeconds = seconds }, token);
            };

            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(http =>
                RateLimitPartition.GetFixedWindowLimiter(ClientKey(http), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RequestsPerMinute,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                }));

            options.AddPolicy(CreateFamily, http =>
                RateLimitPartition.GetFixedWindowLimiter(ClientKey(http), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = FamiliesPerHour,
                    Window = TimeSpan.FromHours(1),
                    QueueLimit = 0,
                }));

            options.AddPolicy(Lookup, http =>
                RateLimitPartition.GetFixedWindowLimiter(ClientKey(http), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = LookupsPerMinute,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                }));
        });
}
