#!/bin/bash

# Deploy NGINX CloudLens to OpenShift - Production Version
# Based on successful deployment to Keysight OpenShift Cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 🚀 Deploying NGINX CloudLens to Keysight OpenShift Cluster ===${NC}"
echo "Deployment started at: $(date)"

# Configuration
NAMESPACE="cloudlens"
RELEASE_NAME="nginx-cloudlens"
CLUSTER_API="https://api.keysight-aro-prod.westus2.aroapp.io:6443"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 succeeded${NC}"
    else
        echo -e "${RED}❌ $1 failed${NC}"
        exit 1
    fi
}

# Step 1: Prerequisites Check
print_section "📋 CHECKING PREREQUISITES"

# Check if logged in to OpenShift
if ! oc whoami &> /dev/null; then
    echo -e "${RED}❌ Error: Not logged in to OpenShift${NC}"
    echo -e "${YELLOW}Please login first:${NC}"
    echo -e "  oc login ${CLUSTER_API} -u kubeadmin -p <password>"
    exit 1
fi

echo -e "${GREEN}✅ Logged in as: $(oc whoami)${NC}"
echo -e "${GREEN}✅ Cluster: $(oc whoami --show-server)${NC}"

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Error: Helm is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install helm${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Helm version: $(helm version --short)${NC}"

# Verify chart files
if [[ ! -f "Chart.yaml" ]]; then
    echo -e "${RED}❌ Error: Chart.yaml not found${NC}"
    echo -e "${YELLOW}Make sure you're in the Helm chart directory${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Helm chart found: $(grep 'name:' Chart.yaml)${NC}"

# Step 2: Namespace Handling
print_section "📁 NAMESPACE MANAGEMENT"

# Remove namespace.yaml if it exists (to avoid conflicts)
if [[ -f "templates/namespace.yaml" ]]; then
    echo -e "${YELLOW}⚠️  Found namespace.yaml - removing to avoid conflicts${NC}"
    mv templates/namespace.yaml templates/namespace.yaml.disabled 2>/dev/null || true
    check_success "Disabled namespace.yaml"
fi

# Check if namespace exists
if oc get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  Namespace '$NAMESPACE' already exists${NC}"
    
    # Check for existing Helm release
    if helm list -n $NAMESPACE 2>/dev/null | grep -q "^${RELEASE_NAME}"; then
        echo -e "${YELLOW}⚠️  Found existing Helm release '${RELEASE_NAME}'${NC}"
        echo -n "Do you want to upgrade the existing release? (y/n): "
        read -r response
        if [[ "$response" != "y" ]]; then
            echo "Deployment cancelled"
            exit 0
        fi
        HELM_ACTION="upgrade"
    else
        HELM_ACTION="install"
    fi
else
    echo -e "${GREEN}✅ Namespace '$NAMESPACE' will be created${NC}"
    HELM_ACTION="install"
fi

# Step 3: Add serviceAccount to values.yaml if missing
print_section "⚙️ CONFIGURATION CHECK"

if ! grep -q "serviceAccount:" values.yaml 2>/dev/null; then
    echo -e "${YELLOW}📝 Adding serviceAccount configuration to values.yaml...${NC}"
    cat >> values.yaml << 'EOF'

# Service Account
serviceAccount:
  create: true
  name: ""
EOF
    check_success "Added serviceAccount configuration"
else
    echo -e "${GREEN}✅ serviceAccount configuration already present${NC}"
fi

# Step 4: Deploy with Helm
print_section "🚀 HELM DEPLOYMENT"

echo -e "${BLUE}Executing: helm ${HELM_ACTION} ${RELEASE_NAME} . --create-namespace --namespace ${NAMESPACE}${NC}"

if helm $HELM_ACTION $RELEASE_NAME . \
    --create-namespace \
    --namespace $NAMESPACE \
    --timeout 5m \
    --wait=false; then
    check_success "Helm ${HELM_ACTION}"
else
    echo -e "${RED}❌ Helm deployment failed${NC}"
    echo -e "${YELLOW}Checking for common issues...${NC}"
    
    # Check if it's a namespace issue
    if helm list -a -n $NAMESPACE | grep -q failed; then
        echo -e "${YELLOW}Cleaning up failed release...${NC}"
        helm delete $RELEASE_NAME -n $NAMESPACE 2>/dev/null || true
        echo -e "${YELLOW}Please run the script again${NC}"
    fi
    exit 1
fi

# Step 5: Grant SCC Permissions (CRITICAL!)
print_section "🔐 SECURITY CONTEXT CONFIGURATION"

echo -e "${YELLOW}⚠️  CRITICAL STEP: Granting anyuid SCC permissions${NC}"
echo -e "${BLUE}This allows pods to run with the required user ID${NC}"

if oc adm policy add-scc-to-user anyuid -z ${RELEASE_NAME} -n $NAMESPACE; then
    check_success "Granted anyuid SCC permissions"
else
    echo -e "${RED}❌ Failed to grant SCC permissions${NC}"
    echo -e "${YELLOW}Try manually: oc adm policy add-scc-to-user anyuid -z ${RELEASE_NAME} -n ${NAMESPACE}${NC}"
fi

# Step 6: Wait for Pods
print_section "⏳ WAITING FOR PODS TO START"

echo "Waiting for DaemonSets to create pods..."
sleep 5

# Check DaemonSets
DAEMONSETS=$(oc get daemonsets -n $NAMESPACE -l app.kubernetes.io/name=nginx-cloudlens --no-headers 2>/dev/null | wc -l)
echo -e "${BLUE}Found $DAEMONSETS DaemonSets${NC}"

# Wait for pods with timeout
echo -n "Waiting for pods to be ready"
TIMEOUT=180
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    READY_PODS=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=nginx-cloudlens --no-headers 2>/dev/null | grep -c "Running" || true)
    TOTAL_PODS=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=nginx-cloudlens --no-headers 2>/dev/null | wc -l)
    
    if [ $READY_PODS -gt 0 ]; then
        echo -ne "\r${GREEN}Waiting for pods to be ready... ($READY_PODS/$TOTAL_PODS running)${NC}"
        
        # Check if all expected pods are running
        WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers | wc -l)
        EXPECTED_PODS=$((WORKER_NODES * 3))
        
        if [ $READY_PODS -eq $EXPECTED_PODS ]; then
            echo -e "\n${GREEN}✅ All $READY_PODS pods are running!${NC}"
            break
        fi
    else
        echo -n "."
    fi
    
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo ""

# Step 7: Deployment Status
print_section "📊 DEPLOYMENT STATUS"

# Pods
echo -e "\n${GREEN}📦 Pods:${NC}"
oc get pods -n $NAMESPACE -o wide | grep -E "NAME|nginx" || echo "No pods found"

# Services
echo -e "\n${GREEN}🔌 Services:${NC}"
oc get svc -n $NAMESPACE | grep -E "NAME|nginx" || echo "No services found"

# Routes
echo -e "\n${GREEN}🌐 Routes:${NC}"
oc get route -n $NAMESPACE | grep -E "NAME|nginx" || echo "No routes found"

# DaemonSets
echo -e "\n${GREEN}🔧 DaemonSets:${NC}"
oc get daemonsets -n $NAMESPACE | grep -E "NAME|nginx" || echo "No daemonsets found"

# Step 8: Access Information
print_section "🎉 DEPLOYMENT COMPLETE"

# Get route URL
ROUTE_URL=$(oc get route $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [[ -n "$ROUTE_URL" ]]; then
    echo -e "${GREEN}✅ Application is accessible at:${NC}"
    echo -e "${BLUE}   HTTP:  http://${ROUTE_URL}${NC}"
    echo -e "${BLUE}   HTTPS: https://${ROUTE_URL}${NC}"
    echo ""
    echo -e "${YELLOW}📌 Note: Both HTTP and HTTPS work without redirects${NC}"
    
    # Test the endpoint
    echo -e "\n${GREEN}🧪 Testing the endpoint...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${ROUTE_URL}" 2>/dev/null || echo "failed")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✅ Application is responding! (HTTP $HTTP_CODE)${NC}"
        
        # Open in browser on macOS
        if [[ "$OSTYPE" == "darwin"* ]] && command -v open &> /dev/null; then
            echo -e "\n${GREEN}🌐 Opening in your browser...${NC}"
            open "http://${ROUTE_URL}"
        fi
    else
        echo -e "${YELLOW}⚠️  Application might still be starting up (HTTP $HTTP_CODE)${NC}"
        echo -e "${YELLOW}   Try accessing in a few moments${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Route not found. The application might still be deploying.${NC}"
    echo -e "${YELLOW}   Check route with: oc get route -n $NAMESPACE${NC}"
fi

# Step 9: Summary and Commands
print_section "📝 USEFUL COMMANDS"

cat << EOF
${GREEN}View logs:${NC}
  oc logs -l app.kubernetes.io/name=nginx-cloudlens -n $NAMESPACE -c nginx

${GREEN}Watch pods:${NC}
  oc get pods -n $NAMESPACE -w

${GREEN}Test each pod:${NC}
  for pod in \$(oc get pods -n $NAMESPACE -o name | grep nginx); do 
    echo "=== \$pod ==="
    oc exec -n $NAMESPACE \$pod -c nginx -- curl -s localhost:8080 | grep -o "Pod Name:.*" | head -1
  done

${GREEN}Port forward (if route not working):${NC}
  oc port-forward -n $NAMESPACE svc/$RELEASE_NAME 8080:80
  # Then access at http://localhost:8080

${GREEN}Check deployment issues:${NC}
  oc describe pods -n $NAMESPACE
  oc get events -n $NAMESPACE --sort-by='.lastTimestamp'

${GREEN}To uninstall:${NC}
  helm uninstall $RELEASE_NAME -n $NAMESPACE
  oc delete namespace $NAMESPACE
EOF

# Step 10: Final Summary
print_section "✨ DEPLOYMENT SUMMARY"

WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers | wc -l)
RUNNING_PODS=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/name=nginx-cloudlens --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
EXPECTED_PODS=$((WORKER_NODES * 3))

echo -e "${BLUE}Cluster:${NC} $(oc whoami --show-server)"
echo -e "${BLUE}Namespace:${NC} $NAMESPACE"
echo -e "${BLUE}Release:${NC} $RELEASE_NAME"
echo -e "${BLUE}Worker Nodes:${NC} $WORKER_NODES"
echo -e "${BLUE}Expected Pods:${NC} $EXPECTED_PODS (3 per worker node)"
echo -e "${BLUE}Running Pods:${NC} $RUNNING_PODS"

if [[ $RUNNING_PODS -eq $EXPECTED_PODS ]]; then
    echo -e "\n${GREEN}🎉 SUCCESS! All $RUNNING_PODS pods are running perfectly!${NC}"
    echo -e "${GREEN}🌈 Your colorful 'Welcome to Keysight OpenShift Cluster' page is ready!${NC}"
else
    echo -e "\n${YELLOW}⚠️  Only $RUNNING_PODS out of $EXPECTED_PODS pods are running${NC}"
    echo -e "${YELLOW}   Some pods might still be starting. Check with:${NC}"
    echo -e "${YELLOW}   oc get pods -n $NAMESPACE${NC}"
fi

echo -e "\n${BLUE}Deployment completed at: $(date)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit successfully
exit 0