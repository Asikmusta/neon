pipeline {
    agent any

    stages {
        stage('Create OpenShift Resources') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject('neon-app') {
                            // Create ImageStreams if they don't exist
                            if (!openshift.selector('is', 'nginx').exists()) {
                                openshift.create('''apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: nginx''')
                            }
                            
                            if (!openshift.selector('is', 'neon-app').exists()) {
                                openshift.create('''apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: neon-app''')
                            }

                            // Create BuildConfig if it doesn't exist
                            if (!openshift.selector('bc', 'neon-app').exists()) {
                                openshift.create('''apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: neon-app
spec:
  source:
    type: Binary
    binary: {}
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
      from:
        kind: ImageStreamTag
        name: nginx:latest
  output:
    to:
      kind: ImageStreamTag
      name: neon-app:latest''')
                            }

                            // Create DeploymentConfig if it doesn't exist
                            if (!openshift.selector('dc', 'neon-app').exists()) {
                                openshift.create('''apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: neon-app
spec:
  replicas: 1
  selector:
    app: neon-app
  template:
    metadata:
      labels:
        app: neon-app
    spec:
      containers:
      - name: neon-app
        image: neon-app:latest
        ports:
        - containerPort: 80''')
                                
                                // Expose the service
                                openshift.selector('dc', 'neon-app').expose()
                            }
                        }
                    }
                }
            }
        }

        stage('Build Application') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject('neon-app') {
                            def build = openshift.selector('bc', 'neon-app').startBuild('--from-dir=.', '--wait')
                            echo "Build ${build.name()} completed"
                            
                            // Get build logs
                            def logs = openshift.selector("build", build.name()).logs()
                            echo "Build logs:\n${logs}"
                        }
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject('neon-app') {
                            // Wait for deployment to complete
                            def dc = openshift.selector('dc', 'neon-app')
                            dc.untilEach {
                                return it.object().status.availableReplicas == 1
                            }
                            
                            // Get route URL
                            def route = openshift.selector('route', 'neon-app').object()
                            echo "Application deployed at: http://${route.spec.host}"
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            echo "Pipeline failed - checking for errors"
            script {
                openshift.withCluster() {
                    openshift.withProject('neon-app') {
                        // Get failed builds
                        def builds = openshift.selector('build').objects()
                        builds.each { build ->
                            if (build.status.phase == 'Failed') {
                                echo "Failed build logs (${build.metadata.name}):"
                                echo openshift.selector("build", build.metadata.name).logs()
                            }
                        }
                        
                        // Get pod status
                        echo "Current pod status:"
                        echo openshift.selector('pods').describe()
                    }
                }
            }
        }
    }
}
