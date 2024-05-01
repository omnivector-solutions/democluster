# democluster

This project contains the democluster image producing codebase.


#### Tuning
Use environment variables to set parameters for the environment setup:
The environment variables `JG_VERSION` and `ENV` are exposed as tunables
to enable customizing the `democluster` for development purposes.

Non-optional environment variables:
- CLIENT_ID
- CLIENT_SECRET

Optional Environment Variables:
- ENV: The non-production environment to include in API URLs. (e.g. "staging", "dev", etc)
- DOMAIN: The non-standard domain for API URLs. (e.g. "private-vantage.io")
- JG_VERSION: The specific version of the jobbergate-agent to install (e.g. 4.4.0)

Example
```bash
CLIENT_ID=aset-fc8b1039-faa7-47b1-967a-c1a55c418740 \
CLIENT_SECRET=9mWa98GbTJMcBZhinfy08aqHPyQWZUn7tH_XrAGLiYE \
ENV=staging \
JG_VERSION=4.3.1 \
./public-scripts/deploy-democluster.sh
```

###### Copyright
Omnivector &copy; 2024 <admin@omnivector.soloutions>
