// ---------------------------------------------------------------------------
// Jenkinsfile — CloudeDX 저장소에 둔다. reluxe-gitops가 아니다.
//
// 🔴 같은 저장소에 두면 무한 루프가 난다.
//    Jenkins가 빌드 → values.yaml에 태그 커밋 → 그 커밋이 Jenkins를 다시 깨움
//    → 무한 반복. 커밋하는 곳(reluxe-gitops)과 Jenkins를 깨우는 곳(CloudeDX)이
//    달라야 한다. (④ 문서 0-A)
//
// 잡 구조: lint → test → build(needs) → chart lint → update gitops
// 배포는 하지 않는다. Argo CD가 가져간다. (④ 문서 7장)
// ---------------------------------------------------------------------------
pipeline {
    agent { label 'buildah' }   // helm-values/jenkins.yaml의 Buildah 파드 템플릿

    environment {
        // 🔴 문서 0-C IP 대역표와 반드시 일치해야 함. AWS에서는 ECR 주소로 교체.
        REGISTRY      = '192.168.56.15:30500'
        GITOPS_REPO   = 'https://github.com/jpnjb0918-glitch/reluxe-gitops.git'
        VALUES_FILE   = 'values-vagrant.yaml'   // AWS 파이프라인에서는 values-aws.yaml
        IMAGE_TAG     = "${env.GIT_COMMIT.take(7)}"   // 태그 = 커밋 해시 7자리
    }

    stages {
        stage('lint') {
            steps {
                sh 'uv run ruff check .'
            }
        }

        stage('test') {
            steps {
                // postgres:16 사이드카 + alembic upgrade + alembic check + pytest
                // 상세 구성은 .github/workflows/ci.yml과 동일한 잡 구조를 따른다.
                sh '''
                    docker run -d --name test-db \
                      -e POSTGRES_PASSWORD=test -e POSTGRES_DB=reluxe_test \
                      -p 5433:5432 postgres:16
                    sleep 5
                    uv run alembic upgrade head
                    uv run alembic check
                    uv run pytest
                '''
            }
            post {
                always { sh 'docker rm -f test-db || true' }
            }
        }

        stage('build') {
            steps {
                // 🔴 k3s는 containerd라 docker build가 안 된다. Buildah를 쓴다.
                //    (Kaniko는 2025년 6월 아카이브됨)
                sh """
                    buildah bud -f dockerfile.backend -t ${REGISTRY}/reluxe-backend:${IMAGE_TAG} .
                    buildah bud -f dockerfile.crawler -t ${REGISTRY}/reluxe-crawler:${IMAGE_TAG} .
                    buildah push --tls-verify=false ${REGISTRY}/reluxe-backend:${IMAGE_TAG}
                    buildah push --tls-verify=false ${REGISTRY}/reluxe-crawler:${IMAGE_TAG}
                """
            }
        }

        stage('chart lint') {
            steps {
                // reluxe-gitops를 임시로 받아 차트가 실제로 렌더링되는지만 검증
                sh """
                    git clone --depth 1 ${GITOPS_REPO} gitops-check
                    helm lint gitops-check/charts/reluxe
                    helm template gitops-check/charts/reluxe -f gitops-check/charts/reluxe/${VALUES_FILE}
                """
            }
        }

        stage('update gitops') {
            steps {
                // 🔴 이 stage만 reluxe-gitops에 커밋한다. Jenkins는 클러스터를 만지지 않는다.
                withCredentials([usernamePassword(
                        credentialsId: 'gitops-push-token',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN')]) {
                    sh """
                        rm -rf gitops-update
                        git clone https://\${GIT_USER}:\${GIT_TOKEN}@${GITOPS_REPO.replace('https://', '')} gitops-update
                        cd gitops-update/charts/reluxe
                        sed -i "s/^  tag: .*/  tag: ${IMAGE_TAG}/" ${VALUES_FILE}
                        git config user.email 'jenkins@reluxe.local'
                        git config user.name 'jenkins-bot'
                        git commit -am "ci: bump image tag to ${IMAGE_TAG}" || echo "변경사항 없음"
                        git push
                    """
                }
            }
        }
    }
}
// 배포는 여기서 하지 않는다 — Argo CD의 selfHeal이 위 커밋을 감지해 가져간다.
