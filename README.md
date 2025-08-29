# democluster

This project contains the democluster image producing codebase.

## Development Setup

This project uses [uv](https://docs.astral.sh/uv/) for dependency management. To get started:

```bash
# Install dependencies
uv sync

# Install development dependencies
uv sync --extra dev

# Run the image-factory tool
uv run image-factory --help

# Build the democluster image
uv run image-factory build democluster
```

#### Tuning
The environment variables `JG_VERSION`, `VTG_VERSION` and `ENV` are exposed as tunables
to enable customizing the `democluster` for development purposes.

Example
```bash
ENV=dev JG_VERSION=4.3.1 VTG_VERSION=2.3.0 \
  ./public-scripts/deploy-democluster.sh \
      aset-fc8b1039-faa7-47b1-967a-c1a55c418740 \
      9mWa98GbTJMcBZhinfy08aqHPyQWZUn7tH_XrAGLiYE
```

###### Copyright
Omnivector &copy; 2024 <admin@omnivector.soloutions>
