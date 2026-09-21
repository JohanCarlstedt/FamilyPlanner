# Putting the server on the internet

Until now the app has talked to a Mac on the home network, which means it
works at home and nowhere else. This is what it takes to make it answer
from a bus.

What the server holds: opaque envelopes, the key directory, wake
schedules, blobs it cannot read. What it does not hold: anything readable.
Whoever runs the machine still sees metadata — which device synced when,
which devices are in a conversation, how big a photo was — so it is worth
it being your machine, but it is not a machine that can read the family's
messages.

## Which server an app talks to

The address is compiled in as a **default** (`API_BASE_URL`), and pinned
the moment a family is created or joined — stored beside the device
secret, cleared only by unbinding. After that the install talks to that
server however often the default changes underneath it.

That is a safety belt, not a moving van. A device's identity is
registered on one server; a build that silently pointed a paired phone
somewhere else would have every request refused by a host that has never
heard of it, which on screen is indistinguishable from a wiped install.
Pinning makes that impossible.

**Moving the server still needs DNS.** A hostname you own, repointed —
which is the whole reason the sslip.io address has to go before anyone
outside the household installs this.

A family running its own server sets it under **Welcome → Use your own
server**, before starting or joining a family. The address is checked
against `/v1/health` before it is accepted, reduced to an origin (a path
would be dropped anyway), and refused over plain http unless it is on the
local network.

## What it needs

- **A hostname you control**, pointing at the server. TLS is not optional:
  iOS refuses plain http off the local network, and it should.
- **~1 GB of RAM and 10 GB of disk** for a family. Postgres holds the
  blobs too, so disk grows with photos (the API caps a family at 2 GB).
- **Docker with the compose plugin.**

## Once, on a new machine

Hetzner, Fastly, whoever — any small Linux box. These are the Debian
commands; the equivalents work elsewhere.

1. **Point the DNS.** An A record (and AAAA if the machine has IPv6) from
   the hostname to the machine's address. Do this first: the certificate
   cannot be issued until it resolves.

2. **A user that isn't root**, with docker:
   ```bash
   adduser family && usermod -aG docker family
   ```
   Copy your SSH key to it, then turn off password logins entirely in
   `/etc/ssh/sshd_config` (`PasswordAuthentication no`). Most of what
   hammers a new server is a password guesser.

3. **Only 22, 80 and 443 open.** Postgres is on the compose network and
   published nowhere; keep it that way.
   ```bash
   ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw enable
   ```

4. **Unattended security updates**, because nobody remembers:
   ```bash
   apt install unattended-upgrades && dpkg-reconfigure -plow unattended-upgrades
   ```

5. **The first deploy from your Mac:**
   ```bash
   scripts/deploy.sh family@<address>
   ```
   It will fail on the missing `.env` — that is expected, it is not
   something a laptop should be able to write.

6. **Fill in the server's own configuration**, on the server:
   ```bash
   cd family/infra && cp .env.example .env && nano .env
   ```
   `DOMAIN`, `ACME_EMAIL`, and a password from `openssl rand -base64 32`.
   Keep that password in your password manager: it is not derivable from
   anything and the database is nothing without it.

7. **Push, if you want it** — put the Firebase service-account key at
   `family/infra/secrets/firebase-service-account.json` on the server
   (`mkdir -p secrets` first, `chmod 600` after). Without it the server
   logs wakes instead of sending them, and phones fall back to reminders
   they schedule themselves.

8. **Deploy again.** Caddy gets the certificate within seconds of the
   first start, and `https://<domain>/v1/health` answers.

## Every time after that

```bash
scripts/deploy.sh family@<address>
```

It sends `backend/` and `infra/`, rebuilds the API image, restarts, and
waits for the health endpoint — printing the container logs if it never
answers. Volumes survive; `.env` and `secrets/` are never sent.

The schema is applied on start (`Database__ApplyMigrations`). Migrations
here are expand-contract, so a phone still running the previous build
keeps working through a deploy — which is the whole point, since you
cannot make five phones update at once.

## Pointing the app at it

The API address is compiled into the app, so a new server means new
builds:

```bash
scripts/ios-testflight.sh https://<domain>
cd app/apps/family && flutter build apk --release --dart-define=API_BASE_URL=https://<domain>
```

A phone's identity and keys live in the app's own storage, not on the
server, so a rebuild pointed elsewhere keeps them — but it then talks to
a server that has never heard of that device. So bring the database
across rather than starting empty.

## Moving the family across

With the home server stopped, from the Mac:

```bash
pg_dump -h localhost -p 5433 -U family --no-owner family | gzip > family.sql.gz
scp family.sql.gz family@<address>:
ssh family@<address> 'cd family/infra && gunzip -c ~/family.sql.gz | docker compose exec -T postgres psql -U family family'
```

Restore into the database as compose created it and before anyone has
used it — the schema is already there from the first start, and an
existing row would collide. Then install the rebuilt app on each phone
(`adb install -r` on Android keeps its data; on iOS, TestFlight over a
cable install does not).

Everything travels: devices, keys, envelopes, blobs, schedules. Nothing
on the phones has to change, because as far as they are concerned the
server simply moved address.

## Two things that will bite

**The API runs as the user that owns `infra/secrets`.** The image has a
non-root user of its own, which cannot read a `0600` file belonging to
someone else. Get this wrong and the push key looks unconfigured — except
that .NET stops the whole host when a background service throws, so the
API does not fall back to logging wakes: it crashes, restarts, crashes.
`APP_UID` in `.env` if the deploy user is not 1000.

**The schema is applied on start, not by hand.** A deploy that changes
the schema and a phone still running last week's build have to coexist,
which is why migrations here are expand-contract.

## Backups

A container dumps the database nightly to the `backups` volume and keeps
a fortnight. That covers a bad deploy or a dropped table; it does not
cover the machine disappearing, since the dumps are on it. Pull them down
regularly — from your Mac:

```bash
ssh family@<address> 'docker run --rm -v family_backups:/b alpine tar cf - /b' > family-backups.tar
```

Restoring, with the stack up:

```bash
gunzip -c family-YYYYMMDDTHHMMSSZ.sql.gz | docker compose exec -T postgres psql -U family family
```

Test that once while nothing depends on it. A backup nobody has restored
is a hope, not a backup.

## Knowing when it breaks

`.github/workflows/watch-server.yml` asks the server for `/v1/health`
every fifteen minutes from GitHub's machines — somewhere other than the
server, because a machine cannot report that it has stopped. It also
checks the certificate has more than a fortnight left, which catches
renewal quietly failing. A failed scheduled workflow emails the
repository owner, and that email is the alarm.

It needs the address once, as a repository variable rather than a line in
the file, because the repository is public:

```bash
gh variable set FAMILY_API_URL --body https://<your-server>
```

Two things about GitHub's schedule: it runs jobs late when busy, so
fifteen minutes means "about four times an hour", and it disables
scheduled workflows in a repository with no commits for 60 days.

## What is still missing

- **A backup that leaves the machine.** The nightly dump is on the same
  disk as the database it came from.
- **A second region, or any redundancy at all.** This is one machine.
