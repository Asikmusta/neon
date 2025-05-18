pipeline {
    agent any

    stages {
        stage('Create OpenShift Resources') {
            steps {
                script {
                    openshift.withCluster() {
                        // Create project if it doesn't exist
                        if (!openshift.project('neon-app')) {
                            openshift.newProject('neon-app', '--display-name="Neon Application"')
                        }

                        openshift.withProject('neon-app') {
                            // Create required ImageStreams
                            ['nginx', 'neon-app'].each { isName ->
                                if (!openshift.selector('is', isName).exists()) {
                                    openshift.create("""apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: ${isName}""")
                                }
                            }

                            // Create Nginx ImageStream tag
                            openshift.create('''apiVersion: image.openshift.io/v1
kind: ImageStreamTag
metadata:
  name: nginx:latest
image:
  dockerImageReference: nginx:latest''')

                            // Create BuildConfig if not exists
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
    type: Source
    sourceStrategy:
      from:
        kind: ImageStreamTag
        name: nginx:latest
      env:
      - name: NGINX_DOCUMENT_ROOT
        value: /usr/share/nginx/html
  output:
    to:
      kind: ImageStreamTag
      name: neon-app:latest''')
                            }

                            // Create DeploymentConfig if not exists
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
        - containerPort: 80
        volumeMounts:
        - name: webroot
          mountPath: /usr/share/nginx/html
      volumes:
      - name: webroot
        emptyDir: {}
  triggers:
  - type: ConfigChange
  - type: ImageChange
    imageChangeParams:
      automatic: true
      containerNames:
      - neon-app
      from:
        kind: ImageStreamTag
        name: neon-app:latest''')

                                // Create Service and Route
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
                            try {
                                // Start binary build with current directory contents
                                def build = openshift.selector('bc', 'neon-app').startBuild('--from-dir=.', '--wait')
                                
                                // Print build logs for debugging
                                def logs = openshift.selector('build', build.name()).logs()
                                echo "Build Logs:\n${logs}"
                                
                                echo "Build ${build.name()} completed successfully"
                            } catch (Exception e) {
                                error "Build failed: ${e.message}"
                            }
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
                            // Verify deployment is ready
                            def dc = openshift.selector('dc', 'neon-app')
                            dc.untilEach(1) {
                                return it.object().status.readyReplicas == 1
                            }
                            
                            // Get application URL
                            def route = openshift.selector('route', 'neon-app').object()
                            echo "Application is ready at: http://${route.spec.host}"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline execution completed"
        }
        success {
            script {
                openshift.withCluster() {
                    openshift.withProject('neon-app') {
                        def route = openshift.selector('route', 'neon-app').object()
                        echo "SUCCESS: Neon application is available at http://${route.spec.host}"
                    }
                }
            }
        }
        failure {
            echo "FAILURE: Pipeline failed - check logs for details"
            script {
                openshift.withCluster() {
                    openshift.withProject('neon-app') {
                        // Try to get build logs if available
                        try {
                            def builds = openshift.selector('build').objects()
                            builds.each { build ->
                                if (build.status.phase == 'Failed') {
                                    echo "Failed build logs (${build.metadata.name}):"
                                    echo openshift.selector('build', build.metadata.name).logs()
                                }
                            }
                        } catch (Exception e) {
                            echo "Could not retrieve build logs: ${e.message}"
                        }
                    }
                }
            }
        }
    }
}
