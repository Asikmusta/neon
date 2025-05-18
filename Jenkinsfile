pipeline {
    agent any

    stages {
        stage('Create OpenShift Resources') {
            steps {
                script {
                    openshift.withCluster() {
                        // Switch to neon-app project (creates if doesn't exist)
                        openshift.withProject('neon-app') {
                            // Create Nginx ImageStream if not exists
                            if (!openshift.selector('is', 'nginx').exists()) {
                                openshift.create('''apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: nginx
spec:
  tags:
  - name: latest
    from:
      kind: DockerImage
      name: nginx:latest''')
                            }

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
    type: Docker
    dockerStrategy:
      from:
        kind: ImageStreamTag
        name: nginx:latest
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
                            // Start binary build with current directory contents
                            def build = openshift.selector('bc', 'neon-app').startBuild('--from-dir=.', '--wait')
                            echo "Build ${build.name()} completed"
                        }
                    }
                }
            }
        }

        stage('Deploy Application') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject('neon-app') {
                            // Trigger deployment
                            openshift.selector('dc', 'neon-app').rollout().latest()
                            
                            // Get application URL
                            def route = openshift.selector('route', 'neon-app').object()
                            echo "Application deployed: http://${route.spec.host}"
                        }
                    }
                }
            }
        }
    }

    post {
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
        }
    }
}
