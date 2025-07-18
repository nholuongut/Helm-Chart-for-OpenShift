![](https://i.imgur.com/waxVImv.png)
### [View all Roadmaps](https://github.com/nholuongut/all-roadmaps) &nbsp;&middot;&nbsp; [Best Practices](https://github.com/nholuongut/all-roadmaps/blob/main/public/best-practices/) &nbsp;&middot;&nbsp; [Questions](https://www.linkedin.com/in/nholuong/)
<br/>

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&weight=500&size=24&pause=1000&color=F7931E&width=435&lines=Hello%2C+I'm+Nho+Luong🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻🇳🇻)](https://git.io/typing-svg)

# **About Me🇻🇳**
- ✍️ Blogger
- ⚽ Football Player
- ♾️ DevOps Engineer
- ⭐ Open-source Contributor
- 😄 Pronouns: Mr. Nho Luong
- 📚 Lifelong Learner | Always exploring something new
- 📫 How to reach me: luongutnho@hotmail.com

![GitHub Grade](https://img.shields.io/badge/GitHub%20Grade-A%2B-brightgreen?style=for-the-badge&logo=github)
<p align="left"> <img src="https://komarev.com/ghpvc/?username=amanpathak-devops&label=Profile%20views&color=0e75b6&style=flat" alt="amanpathak-devops" /> </p>

# 🚀 NGINX Custom Welcome Helm Chart for OpenShift

A production-ready Helm chart that deploys NGINX with a beautiful custom welcome page across all worker nodes in your OpenShift cluster.

![Status](https://img.shields.io/badge/Status-Production%20Ready-green)
![OpenShift](https://img.shields.io/badge/OpenShift-4.x-red)
![Helm](https://img.shields.io/badge/Helm-3.x-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Contributions](https://img.shields.io/badge/Contributions-Welcome-brightgreen)

## 📋 Table of Contents
- [Overview](#-overview)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [What Makes It Work](#-what-makes-it-work)
- [Architecture](#️-architecture)
- [File Structure](#-file-structure)
- [Deployment Guide](#-deployment-guide)
- [Troubleshooting](#-troubleshooting)
- [Customization](#-customization)
- [Security Considerations](#-security-considerations)

## 🌟 Overview

This Helm chart deploys:
- **9 NGINX pods** (3 per worker node) using DaemonSets
- **Beautiful animated welcome page** with gradient backgrounds and particle effects
- **Dual protocol support** (HTTP and HTTPS) without redirects
- **Full OpenShift integration** with Routes, SCCs, and proper security contexts

## ✨ Features

### Visual Features
- 🎨 **Animated rainbow text** with customizable welcome message
- 🌈 **Purple gradient background** with floating particles
- 💫 **Pulsing logo** with gradient effects
- 📊 **Live pod information** display with glassmorphism effect

### Technical Features
- ⚡ **DaemonSet deployment** - Ensures exactly 3 pods per worker node
- 🔒 **Security Context Constraints** - Properly configured for OpenShift
- 📡 **Dual protocol access** - Both HTTP and HTTPS work independently
- 📊 **Prometheus metrics** - Via nginx-exporter sidecar
- 🔄 **Health checks** - Liveness and readiness probes
- 🛡️ **Network policies** - Secure pod communication

## 📦 Prerequisites

```bash
# 1. OpenShift 4.x cluster
oc version

# 2. Helm 3.x installed
helm version

# 3. Logged into OpenShift
oc login https://api.your-cluster.com:6443
oc whoami

# 4. Sufficient permissions
oc auth can-i create namespace
oc auth can-i create securitycontextconstraints
```

## 🚀 Quick Start

```bash
# Clone or download the Helm chart
cd nginx-custom-welcome/

# Deploy with one command
helm upgrade --install nginx-welcome . \
  --create-namespace \
  --namespace ${PROJECT_NAMESPACE} \
  --wait \
  --timeout 10m

# Get the URL
echo "Access at: http://$(oc get route nginx-welcome -n ${PROJECT_NAMESPACE} -o jsonpath='{.spec.host}')"
```

## 🔧 What Makes It Work

### 1. **Security Context Fix** ⚡
The biggest challenge was OpenShift's Security Context Constraints (SCCs).

**Problem**: Pods tried to run as user 1001, but OpenShift requires UIDs in range [1000770000, 1000779999]

**Solution**: Grant the service account permission to use `anyuid` SCC:
```bash
oc adm policy add-scc-to-user anyuid -z nginx-welcome -n ${PROJECT_NAMESPACE}
```

### 2. **Route Configuration Fix** 🌐
**Problem**: Initial route pointed to port 8443 with edge termination, causing "400 Bad Request"

**Solution**: Point route to port 8080 with `insecureEdgeTerminationPolicy: Allow`:
```yaml
spec:
  port:
    targetPort: 8080  # Changed from 8443
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Allow  # Changed from Redirect
```

### 3. **Namespace Management Fix** 📁
**Problem**: Helm namespace creation conflicts

**Solution**: Use `--create-namespace` flag and let Helm manage it:
```bash
helm install nginx-welcome . --create-namespace --namespace ${PROJECT_NAMESPACE}
```

### 4. **DaemonSet Node Selector** 🖥️
**Key**: DaemonSets use proper node selector to target only worker nodes:
```yaml
nodeSelector:
  node-role.kubernetes.io/worker: ""
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenShift Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Worker 1   │  │  Worker 2   │  │  Worker 3   │         │
│  │             │  │             │  │             │         │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │
│  │ │DaemonSet│ │  │ │DaemonSet│ │  │ │DaemonSet│ │         │
│  │ │    0    │ │  │ │    0    │ │  │ │    0    │ │         │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │
│  │ │DaemonSet│ │  │ │DaemonSet│ │  │ │DaemonSet│ │         │
│  │ │    1    │ │  │ │    1    │ │  │ │    1    │ │         │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │
│  │ │DaemonSet│ │  │ │DaemonSet│ │  │ │DaemonSet│ │         │
│  │ │    2    │ │  │ │    2    │ │  │ │    2    │ │         │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │               Service (LoadBalancer)            │         │
│  └────────────────────────────────────────────────┘         │
│                          │                                   │
│  ┌────────────────────────────────────────────────┐         │
│  │                  OpenShift Route                │         │
│  │  http://nginx-welcome.apps.cluster.com         │         │
│  │  https://nginx-welcome.apps.cluster.com        │         │
│  └────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 📁 File Structure

```
nginx-custom-welcome/
├── Chart.yaml                    # Helm chart metadata
├── values.yaml                   # Default configuration values
├── templates/
│   ├── _helpers.tpl             # Template helper functions
│   ├── configmap.yaml           # 🎨 Contains the beautiful HTML/CSS/JS
│   ├── deployment.yaml          # Creates 3 DaemonSets
│   ├── service.yaml             # LoadBalancer service
│   ├── route.yaml               # OpenShift Route for ingress
│   ├── serviceaccount.yaml      # SA + SecurityContextConstraints
│   ├── networkpolicy.yaml       # Network security rules
│   ├── poddisruptionbudget.yaml # High availability settings
│   └── servicemonitor.yaml      # Prometheus monitoring
└── README.md                    # This file
```

### Key Files Explained

#### `templates/configmap.yaml` - The Magic ✨
Contains the entire custom HTML page with:
- **CSS animations** for gradient backgrounds and rainbow text
- **JavaScript** for floating particles
- **Dynamic content** showing pod/node information

#### `templates/deployment.yaml` - The Workload 🏃
- Creates 3 DaemonSets (nginx-welcome-0, nginx-welcome-1, nginx-welcome-2)
- Each DaemonSet runs on all worker nodes
- Includes init containers for HTML setup and TLS certificate generation

#### `templates/route.yaml` - The Access Point 🌐
- Creates OpenShift Route for external access
- Configured for both HTTP and HTTPS without redirects
- Edge TLS termination with `insecureEdgeTerminationPolicy: Allow`

## 📝 Deployment Guide

### Step 1: Prepare Environment
```bash
# Verify you're in the correct cluster
oc cluster-info
oc get nodes

# Check available worker nodes
oc get nodes -l node-role.kubernetes.io/worker

# Set your project variables
export PROJECT_NAMESPACE="your-project"
export WELCOME_MESSAGE="Welcome to Your OpenShift Cluster"
```

### Step 2: Configure Values (Optional)
Edit `values.yaml` if needed:
```yaml
namespace: your-project           # Target namespace
welcomeMessage: "Welcome to Your OpenShift Cluster"  # Custom message
deployment:
  podsPerNode: 3                 # Pods per worker node
service:
  type: LoadBalancer             # Service type
route:
  host: nginx-welcome.apps.your-cluster.com  # Your route
```

### Step 3: Deploy the Chart
```bash
# Full deployment command with all options
helm upgrade --install nginx-welcome . \
  --create-namespace \
  --namespace ${PROJECT_NAMESPACE} \
  --set welcomeMessage="${WELCOME_MESSAGE}" \
  --wait \
  --timeout 10m \
  --debug

# If namespace already exists
helm upgrade --install nginx-welcome . \
  --namespace ${PROJECT_NAMESPACE} \
  --wait
```

### Step 4: Grant Security Permissions
```bash
# This is CRITICAL - without this, pods won't start
oc adm policy add-scc-to-user anyuid -z nginx-welcome -n ${PROJECT_NAMESPACE}
```

### Step 5: Verify Deployment
```bash
# Check pods (should see 9 total - 3 per worker)
oc get pods -n ${PROJECT_NAMESPACE}

# Check DaemonSets
oc get daemonsets -n ${PROJECT_NAMESPACE}

# Check services
oc get svc -n ${PROJECT_NAMESPACE}

# Check route
oc get route -n ${PROJECT_NAMESPACE}
```

### Step 6: Access the Application
```bash
# Get the URL
ROUTE_URL=$(oc get route nginx-welcome -n ${PROJECT_NAMESPACE} -o jsonpath='{.spec.host}')
echo "HTTP:  http://$ROUTE_URL"
echo "HTTPS: https://$ROUTE_URL"

# Open in browser (macOS)
open "http://$ROUTE_URL"
```

## 🔍 Troubleshooting

### Pods Not Starting
```bash
# Check pod status
oc get pods -n ${PROJECT_NAMESPACE}
oc describe pod <pod-name> -n ${PROJECT_NAMESPACE}

# Check events
oc get events -n ${PROJECT_NAMESPACE} --sort-by='.lastTimestamp'

# Common fix - grant SCC permissions
oc adm policy add-scc-to-user anyuid -z nginx-welcome -n ${PROJECT_NAMESPACE}
```

### 400 Bad Request Error
```bash
# Check route configuration
oc get route nginx-welcome -n ${PROJECT_NAMESPACE} -o yaml

# Ensure targetPort is 8080, not 8443
# Ensure insecureEdgeTerminationPolicy is Allow, not Redirect
```

### Namespace Issues
```bash
# If namespace exists with wrong annotations
oc delete namespace ${PROJECT_NAMESPACE}
helm install nginx-welcome . --create-namespace --namespace ${PROJECT_NAMESPACE}
```

### Security Context Errors
```bash
# Error: "must be in the ranges: [1000770000, 1000779999]"
# Solution:
oc adm policy add-scc-to-user anyuid -z nginx-welcome -n ${PROJECT_NAMESPACE}
oc rollout restart daemonset -n ${PROJECT_NAMESPACE}
```

## 🎨 Customization

### Change Colors
Edit `templates/configmap.yaml`:
```css
/* Purple gradient background */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Rainbow text animation */
background: linear-gradient(45deg, #f093fb 0%, #f5576c 25%, #ffa502 50%, #32ff7e 75%, #7bed9f 100%);
```

### Change Welcome Message
In `values.yaml`:
```yaml
welcomeMessage: "Welcome to Your Custom OpenShift Cluster"
```

Or via Helm install:
```bash
helm install nginx-welcome . --set welcomeMessage="Your Custom Message"
```

### Change Company Logo
In `templates/configmap.yaml`, replace the logo section:
```html
<div class="logo">
  <img src="data:image/svg+xml;base64,YOUR_LOGO_BASE64" alt="Your Company Logo">
</div>
```

### Scale Pods Per Node
In `values.yaml`:
```yaml
deployment:
  podsPerNode: 5  # Change from 3 to 5 pods per node
```

## 🔒 Security Considerations

### Security Context Constraints (SCC)
- Uses `anyuid` SCC to allow custom UIDs
- Runs as non-root user where possible
- Drops unnecessary capabilities
- Uses read-only root filesystem where possible

### Network Policies
- Restricts ingress to OpenShift router
- Allows egress for DNS and HTTPS
- Pod-to-pod communication within namespace

### TLS Configuration
- Self-signed certificates generated automatically
- Edge termination at the route level
- Supports both HTTP and HTTPS independently

## 🧹 Cleanup

```bash
# Uninstall the Helm release
helm uninstall nginx-welcome -n ${PROJECT_NAMESPACE}

# Delete the namespace
oc delete namespace ${PROJECT_NAMESPACE}

# Remove SCC permissions (if granted)
oc adm policy remove-scc-from-user anyuid -z nginx-welcome -n ${PROJECT_NAMESPACE}
```

## 📊 Monitoring

Access Prometheus metrics:
```bash
# Port-forward to a pod
oc port-forward -n ${PROJECT_NAMESPACE} pod/$(oc get pod -n ${PROJECT_NAMESPACE} -o name | head -1 | cut -d/ -f2) 9113:9113

# Access metrics
curl http://localhost:9113/metrics
```

Common metrics available:
- `nginx_http_requests_total` - Total HTTP requests
- `nginx_connections_active` - Active connections
- `nginx_up` - NGINX service status

## 🚀 Advanced Features

### Multi-Environment Support
Deploy to multiple environments:
```bash
# Development
helm install nginx-welcome-dev . -n development --set welcomeMessage="Development Environment"

# Staging
helm install nginx-welcome-stage . -n staging --set welcomeMessage="Staging Environment"

# Production
helm install nginx-welcome-prod . -n production --set welcomeMessage="Production Environment"
```

### Blue-Green Deployment
```bash
# Deploy blue version
helm install nginx-welcome-blue . -n production --set version=blue

# Deploy green version
helm install nginx-welcome-green . -n production --set version=green

# Switch traffic via route
oc patch route nginx-welcome -n production -p '{"spec":{"to":{"name":"nginx-welcome-green"}}}'
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

### Development Guidelines
- Follow Helm best practices
- Test on OpenShift 4.x
- Ensure security context compatibility
- Add appropriate documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔄 Variables Reference

When using this Helm chart, customize these variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `${PROJECT_NAMESPACE}` | Target namespace | `my-project` |
| `${WELCOME_MESSAGE}` | Custom welcome text | `Welcome to My Cluster` |
| `YOUR_LOGO_BASE64` | Base64 encoded logo | `iVBORw0KGgoAAAANSUhEUgAA...` |
| `your-cluster.com` | Your OpenShift cluster domain | `apps.openshift.example.com` |

## 🙏 Acknowledgments

- OpenShift community for security best practices
- Helm community for chart standards
- NGINX team for the excellent web server

![](https://i.imgur.com/waxVImv.png)
# I'm are always open to your feedback🚀
# **[Contact Me🇻]**
* [Name: Nho Luong]
* [Telegram](+84983630781)
* [WhatsApp](+84983630781)
* [PayPal.Me](https://www.paypal.com/paypalme/nholuongut)
* [Linkedin](https://www.linkedin.com/in/nholuong/)

![](https://i.imgur.com/waxVImv.png)
![](Donate.png)