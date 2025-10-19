# Forgejo Runner Debian

A Debian-based Docker image for act-based runners like [Forgejo Actions](https://forgejo.org/docs/latest/admin/actions/) and [Gitea Actions](https://docs.gitea.com/usage/actions/overview) runners. This image provides a stable, minimal environment with Node.js LTS and Docker CLI pre-installed.

## Features

- **Base**: Debian stable-slim
- **Node.js**: Latest LTS version (automatically updated weekly)
- **Docker**: Latest stable Docker CLI with Buildx and Compose plugins
- **Tools**: Git, curl, wget, jq, openssh-client, build-essential
- **Multi-arch**: Supports both amd64 and arm64

## Usage

### With Forgejo Runner

Configure your runner's `config.yml`:

```yaml
runner:
  labels:
    - "debian:docker://ghcr.io/coders-compass/debian-act-runner:latest"
```

### In Your Workflow

```yaml
name: CI

on: [push]

jobs:
  build:
    runs-on: debian
    steps:
      - uses: actions/checkout@v5

      - name: Run tests
        run: |
          node --version
          npm --version
          docker --version
```

## Image Details

- **Registry**: GitHub Container Registry (GHCR)
- **Image**: `ghcr.io/coders-compass/debian-act-runner:latest`
- **Updates**: Automatically rebuilt weekly to include latest security patches
- **Source**: [GitHub Repository](https://github.com/Coders-Compass/debian-act-runner)

## Available Tags

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit from main branch
- `YYYYMMDD` - Weekly scheduled builds

## Verification

After pulling the image, verify installations:

```bash
docker run --rm ghcr.io/coders-compass/debian-act-runner:latest bash -c "
  echo 'Debian:' && cat /etc/debian_version
  echo 'Node.js:' && node --version
  echo 'npm:' && npm --version
  echo 'Docker:' && docker --version
  echo 'Git:' && git --version
"
```

## Building Locally

```bash
git clone https://github.com/Coders-Compass/debian-act-runner.git
cd debian-act-runner
docker build -t debian-act-runner:local .
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details

## Maintainer

[@hungrybluedev](https://github.com/hungrybluedev)

## Acknowledgments

Inspired by [catthehacker/docker_images](https://github.com/catthehacker/docker_images) for the nektos/act project.
