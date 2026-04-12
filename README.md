# CDF Crew website

Static site for [CDF Crew](https://cdfcrew.it/), built with [Hugo](https://gohugo.io/).

## Local development

Install Hugo **v0.160.1+** (or use the same version as CI/Dockerfile), then:

```bash
hugo server
```

Open `http://localhost:1313/`.

## Builds for two environments

- **Production** (`https://cdfcrew.it/`): canonical URLs, indexable `robots.txt`, full sitemap.

```bash
hugo --minify --environment production
```

- **GitHub Pages preview** (private repo Pages): `noindex` + `robots.txt` disallow all. **Edit**
  `config/github/hugo.yaml` and set `baseURL` to your real GitHub Pages URL (including repository
  path prefix for project sites, e.g. `https://org.github.io/repo/`).

```bash
hugo --minify --environment github
```

Output is always `public/`.

## Container image (Kubernetes-friendly)

```bash
docker build -t cdfcrew-website:local .
```

The image serves files with **nginx** (unprivileged) on port **8080**.

## GitHub Actions

`.github/workflows/hugo.yml` builds with `--environment github` and deploys via **GitHub Pages**
(Actions). Enable **Pages → GitHub Actions** in repository settings and align `config/github/hugo.yaml`
`baseURL` with the published URL.
