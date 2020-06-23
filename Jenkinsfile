def SERVICE_GROUP = "sockshop"
def SERVICE_NAME = "payment"
def IMAGE_NAME = "${SERVICE_NAME}"
def REPOSITORY_URL = "https://github.com/SecOpsDemo/payment.git"
def REPOSITORY_SECRET = ""
def SLACK_TOKEN_DEV = ""
def SLACK_TOKEN_DQA = ""

@Library("github.com/opsnow-tools/valve-butler")
def butler = new com.opsnow.valve.v7.Butler()
def label = "worker-${UUID.randomUUID().toString()}"

properties([
  buildDiscarder(logRotator(daysToKeepStr: "60", numToKeepStr: "30"))
])
podTemplate(label: label, containers: [
  containerTemplate(name: "builder", image: "opsnowtools/valve-builder:v0.2.2", command: "cat", ttyEnabled: true, alwaysPullImage: true),
  containerTemplate(name: "go", image: "golang:1.7", command: "cat", ttyEnabled: true)
], volumes: [
  hostPathVolume(mountPath: "/var/run/docker.sock", hostPath: "/var/run/docker.sock"),
  hostPathVolume(mountPath: "/home/jenkins/.draft", hostPath: "/home/jenkins/.draft"),
  hostPathVolume(mountPath: "/home/jenkins/.helm", hostPath: "/home/jenkins/.helm")
]) {
  node(label) {
    stage("Prepare") {
      container("builder") {
        butler.prepare(IMAGE_NAME)
      }
    }
    stage("Checkout") {
      container("builder") {
        try {
          if (REPOSITORY_SECRET) {
            git(url: REPOSITORY_URL, branch: BRANCH_NAME, credentialsId: REPOSITORY_SECRET)
          } else {
            git(url: REPOSITORY_URL, branch: BRANCH_NAME)
          }
        } catch (e) {
          butler.failure(SLACK_TOKEN_DEV, "Checkout")
          throw e
        }

        butler.scan("go")
      }
    }
    stage("Build") {
      container("go") {
        try {
          // butler.go_build() // FIXME
          
          dir(".") {
            sh '''
              mkdir /target && \
              mkdir -p /go/src/github.com/SecOpsDemo/payment && \
              cp -r . /go/src/github.com/SecOpsDemo/payment/ && \
              go get -u github.com/FiloSottile/gvt
            '''
          }

          dir("/go/src/github.com/SecOpsDemo/payment") {
            sh '''
              gvt restore && \
              CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /target/main github.com/SecOpsDemo/payment/cmd/paymentsvc
            '''
          }

          butler.success(SLACK_TOKEN_DEV, "Build")
        } catch (e) {
          butler.failure(SLACK_TOKEN_DEV, "Build")
          throw e
        }
      }
    }
    stage("Tests") {
      container("go") {
        try {
          // butler.go_test() // FIXME
          sh '''
            echo "start test"
          '''
        } catch (e) {
          butler.failure(SLACK_TOKEN_DEV, "Tests")
          throw e
        }
      }
    }
    if (BRANCH_NAME == "master") {
      stage("Build Image") {
        parallel(
          "Build Docker": {
            container("builder") {
              try {
                butler.build_image()
              } catch (e) {
                butler.failure(SLACK_TOKEN_DEV, "Build Docker")
                throw e
              }
            }
          },
          "Build Charts": {
            container("builder") {
              try {
                butler.build_chart()
              } catch (e) {
                butler.failure(SLACK_TOKEN_DEV, "Build Charts")
                throw e
              }
            }
          }
        )
      }
      stage('Scan Image - Prisma Cloud') {
        // Scan the image
        this.VERSION = butler.get_version()
        echo "# scan version: ${VERSION}"
        prismaCloudScanImage ca: '',
          cert: '',
          dockerAddress: 'unix:///var/run/docker.sock',
          image: "docker-registry-devops.soc1.bespin-mss.com/${IMAGE_NAME}:${VERSION}",
          key: '',
          logLevel: 'info',
          podmanPath: '',
          project: '',
          resultsFile: 'prisma-cloud-scan-results.json',
          ignoreImageBuildTime:true
        
        prismaCloudPublish resultsFilePattern: 'prisma-cloud-scan-results.json'
      }
      stage('Deploy Here') {
        container('builder') {
          try {
            // deploy(cluster, namespace, sub_domain, profile)
            butler.deploy('here', 'sock-shop', "${IMAGE_NAME}", 'product')
            butler.success(SLACK_TOKEN_DEV, 'Deploy Here')
          } catch (e) {
            butler.failure(SLACK_TOKEN_DEV, 'Deploy Here')
            throw e
          }
        }
      }
    }
  }
}
