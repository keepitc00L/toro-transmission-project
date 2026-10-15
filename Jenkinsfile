pipeline {
    agent any

    environment {
        IMAGE_NAME    = 'toro-transmission'
        IMAGE_TAG     = "${env.BUILD_NUMBER ?: 'latest'}"
        REGISTRY      = ''   // Leave empty for local Minikube; set to 'docker.io/youruser' for Docker Hub
        K8S_NAMESPACE = 'default'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '📥 Checking out source code...'
                checkout scm
            }
        }

        stage('Lint & Validate') {
            steps {
                echo '🔍 Validating project files...'
                sh '''
                    echo "Checking required files exist..."
                    test -f index.html   && echo "✅ index.html"
                    test -f style.css    && echo "✅ style.css"
                    test -f script.js    && echo "✅ script.js"
                    test -f Dockerfile   && echo "✅ Dockerfile"
                    test -f nginx.conf   && echo "✅ nginx.conf"
                    test -d k8s          && echo "✅ k8s/ directory"
                    echo "All required files present."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Test Container') {
            steps {
                echo '🧪 Running smoke test on container...'
                sh """
                    docker run -d --name toro-test -p 8888:80 ${IMAGE_NAME}:${IMAGE_TAG}
                    sleep 3
                    # Verify the container responds with HTTP 200
                    HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8888/)
                    echo "HTTP response code: \$HTTP_CODE"
                    if [ "\$HTTP_CODE" != "200" ]; then
                        echo "❌ Smoke test failed!"
                        docker stop toro-test && docker rm toro-test
                        exit 1
                    fi
                    echo "✅ Smoke test passed!"
                    docker stop toro-test && docker rm toro-test
                """
            }
        }

        stage('Push to Registry') {
            when {
                expression { env.REGISTRY?.trim() }
            }
            steps {
                echo "📤 Pushing image to registry: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "\$DOCKER_PASS" | docker login -u "\$DOCKER_USER" --password-stdin
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:latest
                        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Deploying to Kubernetes (Minikube)...'
                sh """
                    kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                    kubectl apply -f k8s/service.yaml    -n ${K8S_NAMESPACE}

                    # Force a rolling restart to pick up the new image
                    kubectl set image deployment/toro-transmission \
                        toro-transmission=${IMAGE_NAME}:${IMAGE_TAG} \
                        -n ${K8S_NAMESPACE}

                    # Wait for rollout to finish
                    kubectl rollout status deployment/toro-transmission \
                        -n ${K8S_NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                sh """
                    echo "--- Pods ---"
                    kubectl get pods -l app=toro-transmission -n ${K8S_NAMESPACE}
                    echo ""
                    echo "--- Service ---"
                    kubectl get svc toro-transmission-service -n ${K8S_NAMESPACE}
                    echo ""
                    echo "--- Deployment ---"
                    kubectl get deployment toro-transmission -n ${K8S_NAMESPACE}
                """
            }
        }
    }

    post {
        success {
            echo '''
            ╔══════════════════════════════════════╗
            ║  ✅  PIPELINE COMPLETED SUCCESSFULLY  ║
            ║                                      ║
            ║  Run: minikube service                ║
            ║    toro-transmission-service          ║
            ║  to open the app in your browser.    ║
            ╚══════════════════════════════════════╝
            '''
        }
        failure {
            echo '❌ Pipeline failed. Check the logs above for details.'
        }
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
