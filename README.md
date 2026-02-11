<details>
<summary>TechWorldNana-K8sTutorial_MongoDB_MongoExpress</summary>
<br>
Tutorial link: [Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]](https://www.youtube.com/watch?v=X48VuDVv0do)

Other links:

 - [Managing Secrets using Configuration Filen (K8s Docs)](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-config-file/)

### kubectl apply commands in order
    
    kubectl apply -f mongo-secret.yaml
    kubectl apply -f mongo.yaml
    kubectl apply -f mongo-configmap.yaml 
    kubectl apply -f mongo-express.yaml

### kubectl get commands

    kubectl get pod
    kubectl get pod --watch
    kubectl get pod -o wide
    kubectl get service
    kubectl get secret
    kubectl get all | grep mongodb

### kubectl debugging commands

    kubectl describe pod mongodb-deployment-xxxxxx
    kubectl describe service mongodb-service
    kubectl logs mongo-express-xxxxxx

### give a URL to external service in minikube

    minikube service mongo-express-service
    kubectl port-forward service/mongo-express-service 8081:8081
</details>