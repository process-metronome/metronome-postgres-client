podTemplate(
    cloud: 'kubernetes', 
    namespace: 'jenkins',
    // Host Volumes are used to share data between containers and the host  
    volumes: [
        emptyDirVolume(mountPath: '/root/.docker', memory: false),
        hostPathVolume(mountPath: '/var/lib/docker', hostPath: '/tmp/cache')
    ],
    // Pull secrets should be created in the K8 namespace beforehand
    imagePullSecrets: [ 
        'do-metronome-registry-credential', 
        'github-packages' 
    ],
    containers: [
        containerTemplate(
            name:               'jnlp',
            image:              'docker.pkg.github.com/process-metronome/metronome-jenkins-worker/metronome-jenkins-worker:latest',
            args:               '${computer.jnlpmac} ${computer.name}',
            workingDir:         '/home/jenkins',
            resourceRequestCpu: '200m',
            resourceLimitCpu:   '300m',
            resourceRequestMemory:'256Mi',
            resourceLimitMemory:'512Mi'
        ),
        containerTemplate(
            name:               'docker',
            image:              'docker:19.03.1',
            command:            'sleep 99d',
            workingDir:         '/home/jenkins',
            ttyEnabled:         true,
            privileged:         true,
            envVars: [
                envVar(key: 'DOCKER_HOST', value: 'tcp://localhost:2375'),
                envVar(key: 'REGISTRY', value: 'registry.digitalocean.com/metronome-registry')
            ]          
        ),
        containerTemplate(
            name:               'docker-deamon',
            image:              'docker:19.03.1-dind',
            ttyEnabled:         true,
            privileged:         true,
            envVars: [
                envVar(key: 'DOCKER_TLS_CERTDIR', value: '')
            ]          
        ),
        containerTemplate(
            name:               'doctl',
            image:              'digitalocean/doctl:1.45.0',
            command:            'cat',
            workingDir:         '/home/jenkins',
            ttyEnabled:         true,
            privileged:         true,
            envVars: [
                secretEnvVar(key: 'DIGITALOCEAN_ACCESS_TOKEN', secretName: 'doctl-secret', secretKey: 'do-access-token'),
            ]          
        )
    ]
   ){
  node(POD_LABEL){
    stage("Setup Build Environment"){
      checkout scm

      sh '''
          git rev-parse HEAD > git_commit_id.txt
      '''
      env.GIT_COMMIT_ID = readFile('git_commit_id.txt').trim()
      env.GIT_COMMIT_SHA = env.GIT_COMMIT_ID.substring(0, 7)

      println "GIT Id: ${env.GIT_COMMIT_SHA}"
      println "Build Id: ${env.BUILD_TAG}"
      
      container('doctl'){
          sh '''
              /app/doctl auth init
              /app/doctl registry login
          ''' 
      }
    }
    stage("Build Images"){
      container('docker'){                
        sh '''
            docker build --tag metronome-postgres-client .
            docker tag metronome-postgres-client $REGISTRY/metronome-postgres-client:$GIT_COMMIT_SHA
            docker push $REGISTRY/metronome-postgres-client:$GIT_COMMIT_SHA
        '''
        if (env.BRANCH_NAME == 'master') {
        sh '''
            docker tag metronome-postgres-client $REGISTRY/metronome-postgres-client:latest
            docker push $REGISTRY/metronome-postgres-client:latest
        '''
        } 
      }
    }
  }
}
