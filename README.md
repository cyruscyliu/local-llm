# Local LLM Platform

## Install dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  coreutils \
  curl \
  docker-compose \
  docker.io \
  git \
  jq \
  make \
  nodejs \
  python3 \
  python3-pip
```

## Configure

Create your environment file and update secrets/keys:

```bash
cp .env.example .env
# Then edit .env with your real values.
```

## HTTPS (Internal CA)

This deployment uses a private CA for internal/VPN-only HTTPS. Users must trust
the CA once to avoid browser warnings. Distribute `certs/ca.crt` and have users
install it on their devices:

Windows:

1. Double-click `ca.crt`.
2. Click "Install Certificate".
3. Choose "Local Machine" if prompted.
4. Place in "Trusted Root Certification Authorities".
5. Finish and restart the browser.

macOS:

1. Double-click `ca.crt` (opens Keychain Access).
2. Add to the System keychain.
3. Open the cert, set Trust to "Always Trust".
4. Close and enter admin password.

Ubuntu/Debian:

```bash
sudo cp ca.crt /usr/local/share/ca-certificates/local-llm-ca.crt
sudo update-ca-certificates
```

## Common Commands

```bash
./scripts/start.sh
./scripts/health.sh
./scripts/check-config.sh
./scripts/restart.sh
```

## License

TBD.
