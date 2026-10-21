pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'maxspeed2020'
        IMAGE_NAME      = 'toro-transmission'
        IMAGE_REPO      = "${env.DOCKER_HUB_USER}/${env.IMAGE_NAME}"
        IMAGE_TAG       = "${env.BUILD_NUMBER ?: 'latest'}"
        K8S_NAMESPACE   = 'default'
        CONTAINER_PORT  = '80'
        TEST_PORT       = '8888'
        NODE_PORT       = '30080'
        // Credential IDs configured in Jenkins Credential Store
        DOCKER_CRED_ID  = 'docker-hub-credentials'
        KUBECONFIG_CRED = 'k8s-kubeconfig'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '=========================================='
                echo '📥 STAGE 1: Checking out source code'
                echo '=========================================='
                checkout scm
                sh '''
                    echo "Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
                    echo "Git Branch: $(git branch --show-current 2>/dev/null || echo 'HEAD')"
                '''
            }
        }

        stage('Lint & Validate') {
            steps {
                echo '=========================================='
                echo '🔍 STAGE 2: Validating project structure'
                echo '=========================================='
                sh '''
                    set -e
                    echo "Verifying all required web assets..."
                    test -f index.html        && echo "  [OK] index.html"
                    test -f style.css         && echo "  [OK] style.css"
                    test -f script.js         && echo "  [OK] script.js"
                    test -f logo.png          && echo "  [OK] logo.png"
                    test -f gear_motor_1.png  && echo "  [OK] gear_motor_1.png"
                    test -f gear_motor_2.png  && echo "  [OK] gear_motor_2.png"
                    test -f gear_motor_3.png  && echo "  [OK] gear_motor_3.png"
                    test -f gear_motor_4.png  && echo "  [OK] gear_motor_4.png"

                    echo "Verifying container & orchestration configs..."
                    test -f Dockerfile        && echo "  [OK] Dockerfile"
                    test -f nginx.conf        && echo "  [OK] nginx.conf"
                    test -f k8s/deployment.yaml && echo "  [OK] k8s/deployment.yaml"
                    test -f k8s/service.yaml    && echo "  [OK] k8s/service.yaml"

                    echo "Validating Dockerfile basic syntax..."
                    grep -q "^FROM " Dockerfile && echo "  [OK] Dockerfile has valid FROM instruction"
                    grep -q "^CMD " Dockerfile  && echo "  [OK] Dockerfile has valid CMD instruction"

                    echo "Validating Kubernetes manifests..."
                    grep -q "kind: Deployment" k8s/deployment.yaml && echo "  [OK] Valid Deployment manifest"
                    grep -q "kind: Service" k8s/service.yaml       && echo "  [OK] Valid Service manifest"
                    grep -q "replicas: 2" k8s/deployment.yaml      && echo "  [OK] Confirmed 2 replicas configured"
                    grep -q "type: NodePort" k8s/service.yaml      && echo "  [OK] Confirmed NodePort service configured"

                    echo "✅ All structural and manifest validations passed."
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo '=========================================='
                echo "🐳 STAGE 3: Building Docker Image"
                echo "Repository : ${IMAGE_REPO}"
                echo "Image Tag  : ${IMAGE_TAG}"
                echo '=========================================='
                sh """
                    docker build -t ${IMAGE_REPO}:${IMAGE_TAG} -t ${IMAGE_REPO}:latest .
                    echo "Docker images successfully built:"
                    docker images | grep "${IMAGE_NAME}" | head -n 5
                """
            }
        }

        stage('Test Container') {
            steps {
                echo '=========================================='
                echo '🧪 STAGE 4: Container Smoke Testing'
                echo '=========================================='
                sh """
                    # Clean up any pre-existing test container
                    docker rm -f toro-pipeline-test >/dev/null 2>&1 || true

                    # Set exit trap to guarantee test container cleanup
                    trap 'docker rm -f toro-pipeline-test >/dev/null 2>&1 || true' EXIT

                    echo "Starting test container on port ${TEST_PORT}..."
                    docker run -d --name toro-pipeline-test -p ${TEST_PORT}:80 ${IMAGE_REPO}:${IMAGE_TAG}

                    # Poll container readiness (up to 15 seconds)
                    echo "Waiting for Nginx container to become responsive..."
                    READY=0
                    for i in \$(seq 1 15); do
                        HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:${TEST_PORT}/ || true)
                        if [ "\$HTTP_CODE" = "200" ]; then
                            READY=1
                            echo "Container responded with HTTP 200 OK after \$i second(s)."
                            break
                        fi
                        sleep 1
                    done

                    if [ "\$READY" -ne 1 ]; then
                        echo "❌ ERROR: Container failed to respond with HTTP 200 (last status: \$HTTP_CODE)"
                        docker logs toro-pipeline-test
                        exit 1
                    fi

                    # Verify that the expected site title is present
                    echo "Checking HTML content integrity..."
                    if curl -s http://localhost:${TEST_PORT}/ | grep -q "Toro Transmission"; then
                        echo "✅ Page content verified: 'Toro Transmission' found in payload."
                    else
                        echo "❌ ERROR: Web page body did not contain 'Toro Transmission'!"
                        exit 1
                    fi

                    echo "✅ Container smoke tests passed successfully."
                """
            }
        }

        stage('Docker Hub Push') {
            steps {
                echo '=========================================='
                echo "📤 STAGE 5: Pushing Image to Docker Hub"
                echo "Target: ${IMAGE_REPO}:${IMAGE_TAG} & latest"
                echo '=========================================='
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CRED_ID}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "Authenticating with Docker Hub as \${DOCKER_USER}..."
                        echo "\$DOCKER_PASS" | docker login -u "\$DOCKER_USER" --password-stdin

                        echo "Pushing ${IMAGE_REPO}:${IMAGE_TAG}..."
                        docker push ${IMAGE_REPO}:${IMAGE_TAG}

                        echo "Pushing ${IMAGE_REPO}:latest..."
                        docker push ${IMAGE_REPO}:latest

                        echo "✅ Successfully pushed images to Docker Hub."
                    """
                }
            }
        }

        stage('Kubernetes Deployment') {
            steps {
                echo '=========================================='
                echo '🚀 STAGE 6: Kubernetes Cluster Verification & Deployment'
                echo '=========================================='
                script {
                    // Check if custom KUBECONFIG credential is configured in Jenkins
                    def hasKubeCred = false
                    try {
                        withCredentials([file(credentialsId: env.KUBECONFIG_CRED, variable: 'KUBECONFIG_FILE')]) {
                            hasKubeCred = true
                            sh """
                                export KUBECONFIG="\${KUBECONFIG_FILE}"
                                echo "Checking Kubernetes cluster connectivity via Jenkins Kubeconfig credential..."
                                kubectl cluster-info
                                echo "Applying manifests to namespace: ${K8S_NAMESPACE}..."
                                kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                                kubectl apply -f k8s/service.yaml    -n ${K8S_NAMESPACE}

                                echo "Updating deployment image to ${IMAGE_REPO}:${IMAGE_TAG}..."
                                kubectl set image deployment/toro-transmission toro-transmission=${IMAGE_REPO}:${IMAGE_TAG} -n ${K8S_NAMESPACE}

                                echo "Waiting for rollout to finish..."
                                kubectl rollout status deployment/toro-transmission -n ${K8S_NAMESPACE} --timeout=120s
                            """
                        }
                    } catch (org.jenkinsci.plugins.credentialsbinding.impl.CredentialNotFoundException e) {
                        echo "Kubeconfig credential '${KUBECONFIG_CRED}' not found in Jenkins Credentials Store. Falling back to agent environment ~/.kube/config..."
                        hasKubeCred = false
                    } catch (Exception ex) {
                        if (hasKubeCred) {
                            throw ex
                        }
                    }

                    // Fallback to agent default kubectl if credential was not configured
                    if (!hasKubeCred) {
                        sh """
                            echo "Testing kubectl availability and cluster access..."
                            if ! command -v kubectl >/dev/null 2>&1; then
                                echo "❌ ERROR: kubectl command not found on this Jenkins agent."
                                echo "Please install kubectl on the Jenkins host or agent."
                                exit 1
                            fi

                            if ! kubectl cluster-info >/dev/null 2>&1; then
                                echo "=========================================================================="
                                echo "⚠️  KUBERNETES CONNECTIVITY WARNING / PRE-FLIGHT CHECK FAILED"
                                echo "=========================================================================="
                                echo "The Jenkins agent cannot reach a Kubernetes API server at current context."
                                echo "Current context: \$(kubectl config current-context 2>/dev/null || echo 'None')"
                                echo ""
                                echo "IMPORTANT ARCHITECTURAL NOTE FOR CCA 2:"
                                echo "If Jenkins is running on an AWS EC2 instance, AWS CANNOT route traffic"
                                echo "to a Minikube cluster running on your local private laptop IP (e.g., 192.168.x.x)."
                                echo ""
                                echo "Resolution options:"
                                echo "  1. (Recommended) Run Minikube on the Jenkins host directly:"
                                echo "     minikube start --driver=docker"
                                echo "  2. Or register a Jenkins Inbound Agent running on your local laptop."
                                echo "  3. Or upload your cluster kubeconfig as Secret File credential '${KUBECONFIG_CRED}'."
                                echo "=========================================================================="
                                exit 1
                            fi

                            echo "Cluster connection verified. Applying manifests..."
                            kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                            kubectl apply -f k8s/service.yaml    -n ${K8S_NAMESPACE}

                            echo "Updating deployment image to ${IMAGE_REPO}:${IMAGE_TAG}..."
                            kubectl set image deployment/toro-transmission toro-transmission=${IMAGE_REPO}:${IMAGE_TAG} -n ${K8S_NAMESPACE}

                            echo "Waiting for rollout completion..."
                            kubectl rollout status deployment/toro-transmission -n ${K8S_NAMESPACE} --timeout=120s
                        """
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '=========================================='
                echo '✅ STAGE 7: Verification & Health Audit'
                echo '=========================================='
                sh """
                    echo "=== Kubernetes Deployment Status ==="
                    kubectl get deployment toro-transmission -n ${K8S_NAMESPACE}

                    echo ""
                    echo "=== Replica Verification (Expected: 2) ==="
                    READY_REPLICAS=\$(kubectl get deployment toro-transmission -n ${K8S_NAMESPACE} -o jsonpath='{.status.readyReplicas}')
                    echo "Ready Replicas: \${READY_REPLICAS:-0} / 2"
                    if [ "\${READY_REPLICAS}" != "2" ]; then
                        echo "⚠️ Warning: Ready replicas count is \${READY_REPLICAS}, expected 2."
                    else
                        echo "✅ Confirmed 2/2 replicas are active and healthy."
                    fi

                    echo ""
                    echo "=== Active Pods ==="
                    kubectl get pods -l app=toro-transmission -n ${K8S_NAMESPACE} -o wide

                    echo ""
                    echo "=== Service & NodePort Access ==="
                    kubectl get svc toro-transmission-service -n ${K8S_NAMESPACE}

                    echo ""
                    echo "=== Access Instructions ==="
                    echo "If running on local Minikube:"
                    echo "  Run: minikube service toro-transmission-service --url"
                    echo "If running on cloud/node:"
                    echo "  Open: http://<NODE_IP>:${NODE_PORT}"
                """
            }
        }
    }

    post {
        success {
            echo '''
            ╔══════════════════════════════════════════════════════════════╗
            ║  ✅  TORO TRANSMISSION CI/CD PIPELINE SUCCEEDED             ║
            ║                                                              ║
            ║  • Code Checked out & Validated                              ║
            ║  • Docker Image Built & Smoke-Tested                         ║
            ║  • Docker Hub Pushed: maxspeed2020/toro-transmission         ║
            ║  • Kubernetes Deployed: 2 Replicas Rolling Update            ║
            ║  • Service NodePort 30080 Active                             ║
            ╚══════════════════════════════════════════════════════════════╝
            '''
        }
        failure {
            echo '''
            ╔══════════════════════════════════════════════════════════════╗
            ║  ❌  PIPELINE FAILED                                         ║
            ║  Review stage logs above for root cause and diagnostics.     ║
            ╚══════════════════════════════════════════════════════════════╝
            '''
        }
        always {
            echo '🧹 Cleaning up workspace...'
            cleanWs()
        }
    }
}
