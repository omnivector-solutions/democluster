# democluster

This project contains the democluster image producing codebase.


#### Tuning
The environment variables `JG_VERSION` and `ENV` are exposed as tunables
to enable customizing the `democluster` for development purposes.

Example
```bash
ENV=dev JG_VERSION=4.3.1 \
  ./public-scripts/deploy-democluster.sh \
      aset-fc8b1039-faa7-47b1-967a-c1a55c418740 \
      9mWa98GbTJMcBZhinfy08aqHPyQWZUn7tH_XrAGLiYE
```

###### Copyright
Omnivector &copy; 2024 <admin@omnivector.soloutions>
