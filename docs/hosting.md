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

A phone that already holds a family cannot be repointed by reinstalling:
its identity and its keys live in that install. Moving from the home
server to this one means each device pairs again, so do it before the
family has much history, or accept that the old server's content stays on
the old server.

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

## What is still missing

- **Rate limiting.** The signature check refuses unknown devices cheaply,
  but nothing stops someone hammering the endpoint. Worth adding before
  the hostname is anywhere public.
- **Monitoring.** Nothing tells you the server is down except a family
  member saying the app is stuck.
- **A second region, or any redundancy at all.** This is one machine.
