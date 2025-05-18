pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject() {
                            // Create build config if it doesn't exist
                            if (!openshift.selector('bc', 'neon-app').exists()) {
                                openshift.newBuild('--name=neon-app', '--image-stream=nginx:latest', '--binary')
                            }
                            
                            // Start binary build
                            openshift.selector('bc', 'neon-app').startBuild('--from-dir=.', '--wait')
                        }
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject() {
                            // Create deployment config if it doesn't exist
                            if (!openshift.selector('dc', 'neon-app').exists()) {
                                openshift.newApp('neon-app:latest', '--name=neon-app')
                                
                                // Expose the service
                                openshift.selector('svc', 'neon-app').expose()
                                
                                // Patch the deployment to use the correct port
                                openshift.selector('dc', 'neon-app').patch('{"spec":{"template":{"spec":{"containers":[{"name":"neon-app","ports":[{"containerPort":8080}]}]}}}}')
                            }
                            
                            // Deploy the latest build
                            openshift.selector('dc', 'neon-app').rollout().latest()
                        }
                    }
                }
            }
        }
    }
}
