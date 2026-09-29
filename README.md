# hello-mule-app

A tiny MuleSoft 4 app, built specifically to learn **Docker + Kubernetes + CI/CD (GitHub Actions)**
end to end, hands-on. It exposes two endpoints:

- `GET /api/hello` → returns a JSON greeting
- `GET /health` → returns `{ "status": "UP" }` (used by Docker `HEALTHCHECK` and Kubernetes probes)

## Project layout

```
hello-mule-app/
├── pom.xml                          # Maven build (mule-maven-plugin + MUnit)
├── mule-artifact.json                # Mule app descriptor
├── src/main/mule/hello-app.xml       # the actual flows
├── src/main/resources/config.properties
├── src/test/munit/hello-app-test-suite.xml   # automated tests, run in CI
├── Dockerfile                        # multi-stage build → runtime image
├── Dockerfile.selfcontained          # alternate build if you have the Mule EE zip instead of registry access
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── .github/workflows/ci-cd.yml       # the GitHub Actions pipeline
```

## How the pieces connect

```
git push  →  GitHub Actions triggers
              │
              ├─ Job 1: build-and-test    (mvn package + MUnit tests)
              │
              ├─ Job 2: docker-build-push (build image, push to ghcr.io)
              │
              └─ Job 3: deploy-to-kubernetes (kubectl apply + rollout)
```

This is exactly the pipeline shape described in the earlier Q&A guide — you're now going to run it for real.

---

## Step 1 — Push this to your own GitHub repo

From inside this extracted folder:

```bash
git init
git add .
git commit -m "Initial commit: hello-mule-app"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/pythonone-mule-demo.git
git push -u origin main
```

(Create the empty repo on GitHub first — no README/gitignore, so there's no merge conflict.)

As soon as you push, go to the **Actions** tab on GitHub — you'll see the workflow start running automatically.

## Step 2 — Watch Job 1 and 2 pass

- **build-and-test** will fail right now unless you also have access to MuleSoft's Maven repository credentials
  configured as GitHub Actions secrets (`MULESOFT_USERNAME` / `MULESOFT_PASSWORD` — MuleSoft's release repo needs
  authentication for some artifacts). If it fails on artifact resolution, that's expected first-run friction — see
  "Common first-run issues" below.
- **docker-build-push** only runs on a push to `main` (not on PRs), and needs the `Dockerfile` to actually build —
  see Step 3, this is the one manual piece.

## Step 3 — The one manual piece: the Mule runtime base image

MuleSoft's runtime is licensed software, so it can't be baked into a Dockerfile pulled from a public registry.
Pick ONE of these:

**Option A — you have Anypoint Platform / private registry access:**
Log in to MuleSoft's Docker registry (`docker login anypointsupport.docker.scm.mulesoft.com`) and the included
`Dockerfile` will work as-is.

**Option B — you only have the Mule EE Standalone zip:**
Download it from Anypoint Platform → Runtime Manager → Software, save it as `mule-runtime.zip` in the project
root, and build with:
```bash
docker build -f Dockerfile.selfcontained -t hello-mule-app .
```

If you're just here to learn the **pipeline mechanics** rather than get a real Mule runtime running, you can
temporarily swap the base image in `Dockerfile` for any placeholder (e.g. `FROM eclipse-temurin:17-jre-jammy` with
a dummy `CMD`) just to watch the Docker build/push/deploy stages succeed — then swap back once you have runtime
access.

## Step 4 — Enable the Kubernetes deploy job (optional, once you have a cluster)

1. Get your cluster's kubeconfig file (`~/.kube/config` if using a local cluster like Minikube/Kind, or downloaded
   from your cloud provider).
2. Base64-encode it: `cat ~/.kube/config | base64 -w 0`
3. In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**
   Name: `KUBE_CONFIG`, value: the base64 string from step 2.
4. Edit `k8s/deployment.yaml` and replace `YOUR_GITHUB_USERNAME` in the image line with your actual GitHub username.
5. Push again — Job 3 will now apply the manifests and roll out the image.

## Step 5 — Verify it's running

```bash
kubectl get pods -l app=hello-mule-app
kubectl get svc hello-mule-app-service
kubectl port-forward svc/hello-mule-app-service 8081:80
curl http://localhost:8081/api/hello
```

## Common first-run issues

| Symptom | Likely cause | Fix |
|---|---|---|
| Maven build fails resolving `mule-http-connector` | MuleSoft repo needs auth for some artifacts | Add `MULESOFT_USERNAME`/`MULESOFT_PASSWORD` secrets and a `<server>` block in a `settings.xml`, referenced via `-s settings.xml` in the workflow |
| `docker build` fails pulling base image | No access to MuleSoft's private registry | Use `Dockerfile.selfcontained` (Option B above) |
| `deploy-to-kubernetes` job fails / hangs | No `KUBE_CONFIG` secret set, or cluster unreachable from GitHub's runners | Skip Job 3 for now (comment it out) until you have a cluster reachable from the internet, or use a self-hosted GitHub Actions runner inside your network |
| Pods stuck in `Pending` | No matching node resources, or no Ingress controller installed | `kubectl describe pod <name>` to see the scheduling reason |

## What to try next, to deepen the learning

1. Break the MUnit test on purpose, push, and watch Job 1 fail — this is what CI catching regressions actually
   feels like.
2. Change `replicas: 2` to `replicas: 4` in `deployment.yaml`, push, and watch `kubectl get pods` scale up.
3. Add a `ConfigMap` for `http.port` instead of hardcoding it as an env var, and reference it from the Deployment.
4. Add a manual approval gate before Job 3 (`environment: production` with required reviewers in GitHub) to
   practice Continuous Delivery vs Continuous Deployment.
