@Library('github.com/connexta/cx-pipeline-library@master') _
pipeline {
  agent { label 'linux-small' }
  options {
    buildDiscarder(logRotator(numToKeepStr:'25'))
    disableConcurrentBuilds()
    timestamps()
  }
  stages {
    stage('Build Images') {
      steps {
	    dockerd{}
        sh 'make image'
      }
    }
    stage('Deploy Images') {
      when {
        allOf {
          expression { env.CHANGE_ID == null }
          expression { env.BRANCH_NAME == "master" }
        }
      }
      environment {
        DOCKER_LOGIN = credentials('dockerhub-codicebot')
      }
      steps {
        sh 'docker login -u $DOCKER_LOGIN_USR -p $DOCKER_LOGIN_PSW'
        sh 'make push'
      }
    }
  }
}
