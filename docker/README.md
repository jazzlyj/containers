# Step 1a - Terraform

Create:

- docker-registry namespace
- docker-registry persistent volume
- docker-registry persistent volume claim

The images that are pushed to the registry are placed in a consistent storage location a persistent volume hosted on the node where the registry pod will be running.

The Pod uses a Persistent Volume Claim which will be bound to the newly created volume as a one-to-one mapping

```bash
terraform plan
terraform apply -auto-approve
```

Terraform file: _registry.tf_

# Step 1b - Set K8s context

Create and set both context and namespace to _docker-registry_

See [contexts-and-namespaces](./kubernetes.md#contexts-and-namespaces)

# Step 2 Creating files for authentication

Create self-signed certificates and user authentication to for security of the private Docker registry.

The TLS certificates are created using openssl.

Specify the name, with which we want to access the registry, in the Common Name “/CN=” field.

Here access the registry using the name _docker-registry_.

- Create dir

```bash
mkdir -p registry && cd "$_"
```

- Create certs

Run this command:

```bash
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=docker-registry" -addext "subjectAltName = DNS:docker-registry"
```

Output looks like this:

    Generating a RSA private key
    .........................................++++
    ........++++
    writing new private key to 'certs/tls.key'
    -----

- Use htpasswd to add user authentication for registry access. Credentials for the private registry would be myuser/mypasswd

Run this command:

```bash
docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn dockerreguser dockerregpassword > auth/htpasswd
```

Output looks like this:

    Unable to find image 'registry:2.6.2' locally
    2.6.2: Pulling from library/registry
    486039affc0a: Pulling fs layer
    ba51a3b098e6: Pulling fs layer
    470e22cd431a: Pulling fs layer
    1048a0cdabb0: Pulling fs layer
    ca5aa9d06321: Pulling fs layer
    1048a0cdabb0: Waiting
    ca5aa9d06321: Waiting
    486039affc0a: Verifying Checksum
    486039affc0a: Download complete
    486039affc0a: Pull complete
    1048a0cdabb0: Verifying Checksum
    1048a0cdabb0: Download complete
    470e22cd431a: Download complete
    ba51a3b098e6: Download complete
    ba51a3b098e6: Pull complete
    ca5aa9d06321: Verifying Checksum
    ca5aa9d06321: Download complete
    470e22cd431a: Pull complete
    1048a0cdabb0: Pull complete
    ca5aa9d06321: Pull complete
    Digest: sha256:c4bdca23bab136d5b9ce7c06895ba54892ae6db0ebfc3a2f1ac413a470b17e47
    Status: Downloaded newer image for registry:2.6.2

# Step 3 Using Secrets to mount the certificates

In Kubernetes, a Secret is a resource that will enable you to inject sensitive data into a container when it starts up. This data can be anything like password, OAuth tokens or ssh keys. They can be exposed inside a container as mounted files or volumes or environment variables.

Run this command:

```bash
kubectl create secret tls certs-secret --cert=/path/to/src/terraform-docker-registry/registry/certs/tls.crt --key=/path/to/src/terraform-docker-registry/registry/certs/tls.key
```

_NOTE_ - cant use ~, use full path

Output looks like this:

    secret/certs-secret created

Run this command:

```bash
kubectl create secret generic auth-secret --from-file=/path/to/src/terraform-docker-registry/registry/auth/htpasswd
```

Output looks like this:

    secret/auth-secret created

# Step 4: Creating the Registry Pod

Create the Pod and a corresponding Service to access it.

The image used for the registry is called registry which is downloaded from DockerHub.

The images pushed to this registry will be saved in /var/lib/registry directory internally, hence mount the Persistent Volume using the Claim "registry-pv-claim-${local.name_suffix}" to persist the images permanently.

The environment variables which are required by the registry container are taken care by the Secrets that we mount as volumes.

The Service is named docker-registry, with which we want to access our docker private registry.
Note that this was the exact name that was given in the Common Name “/CN=” field while generating the TLS certificates.

The registry container by default is exposed at port 5000 and we bind our Service to this port accordingly.

Run this command:

```bash
terraform plan
terraform apply -auto-approve
```

Output looks like this:

# Step 5: Allowing access to the registry from all the nodes in the cluster

As noted from the service the registry can be accessed at IPADDR:5000, eg 10.105.244.156.

Note this IPADDR will be different.

Run this command:

```bash
kubectl get all
```

Output looks like this:

    NAME                                          READY   STATUS    RESTARTS   AGE
    pod/docker-registry-pod-docker-registry-dev   1/1     Running   0          164m

    NAME                                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    service/docker-registry-service-docker-registry-dev   ClusterIP   10.105.244.156   <none>        5000/TCP   158m

Add an entry “10.105.244.156 docker-registry” to the /etc/hosts file of all the nodes in the K8s cluster so that this ip-address is resolved to the name: docker-registry
Run this command:

```bash
export REGISTRY_NAME="docker-registry"
export REGISTRY_IP="10.105.244.156"
for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do ssh root@$x "rm -rf /etc/docker/certs.d/$REGISTRY_NAME:5000;mkdir -p /etc/docker/certs.d/$REGISTRY_NAME:5000"; done
```

Output looks like this:

_NOTE_: on minikube deploys ssh into minikube node and edit the /etc/hosts file like so

Run this command:

```bash
minikube ssh
sudo vi /etc/hosts
# add the line
# 10.105.244.156  docker-registry
```

Output looks like this:

Next, copy the tls.crt created earlier as “ca.crt” into a custom /etc/docker/certs.d/docker-registry:5000 directory in all the nodes in our cluster to make sure that our self-signed certificate is trusted by Docker.

_Note_ that the directory that is created inside /etc/docker/certs.d should be having the name of the format<registry_name>:<registry_port>.

This step can be done manually or with the help of a single command from the master node as follows:

Run this command:

```bash
for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do ssh root@$x "rm -rf /etc/docker/certs.d/$REGISTRY_NAME:5000;mkdir -p /etc/docker/certs.d/$REGISTRY_NAME:5000"; done
```

Output looks like this:

_NOTE_: on minikube deploys ssh into minikube node and make the dir and copy the contents of the tls.crt file (noted above)

Run this command:

```bash
minikube ssh
sudo mkdir -p /etc/docker/certs.d/docker-registry:5000
sudo vi ca.crt
```

The forces Docker to verify the self-signed certificate even though it is not signed by a known authority.

# Step 6: Testing the Private Docker Registry

- Login to the registry from the minikube or a control plane node using the credentials created earlier

```bash
docker login docker-registry:5000 -u dockerreguser -p dockerregpassword
```

Output looks like this:

    docker@minikube:/etc/docker/certs.d/docker-registry:5000$
    WARNING! Using --password via the CLI is insecure. Use --password-stdin.
    WARNING! Your password will be stored unencrypted in /home/docker/.docker/config.json.
    Configure a credential helper to remove this warning. See
    https://docs.docker.com/engine/reference/commandline/login/#credentials-store

    Login Succeeded

- Create a Secret of type _docker-registry_ which uses the credentials dockerreguser/dockerregpassword for enabling all the nodes in the cluster to authenticate with the private Docker registry.

```bash
 kubectl create secret docker-registry reg-cred-secret --docker-server=docker-registry:5000 --docker-username=dockerreguser --docker-password=dockerregpassword
```

Output looks like this:

    secret/reg-cred-secret created

- Push a custom image to the private Docker registry

```bash
docker pull nginx
docker tag nginx:latest docker-registry:5000/mynginx:v1
docker push docker-registry:5000/mynginx:v1
```

Output looks like this:

    docker@minikube:~$ docker pull nginx
    Using default tag: latest
    latest: Pulling from library/nginx
    f1f26f570256: Already exists
    7f7f30930c6b: Pull complete
    2836b727df80: Pull complete
    e1eeb0f1c06b: Pull complete
    86b2457cc2b0: Pull complete
    9862f2ee2e8c: Pull complete
    Digest: sha256:2ab30d6ac53580a6db8b657abf0f68d75360ff5cc1670a85acb5bd85ba1b19c0
    Status: Downloaded newer image for nginx:latest
    docker.io/library/nginx:latest
    docker@minikube:~$ docker tag nginx:latest docker-registry:5000/mynginx:v1
    docker@minikube:~$ docker push docker-registry:5000/mynginx:v1
    The push refers to repository [docker-registry:5000/mynginx]
    ff4557f62768: Pushed
    4d0bf5b5e17b: Pushed
    95457f8a16fd: Pushed
    a0b795906dc1: Pushed
    af29ec691175: Pushed
    3af14c9a24c9: Pushed
    v1: digest: sha256:bfb112db4075460ec042ce13e0b9c3ebd982f93ae0be155496d050bb70006750 size: 1570

- Exec a shell onto the docker-registry-pod and list contents of docker registry dir

```bash
kubectl exec docker-registry-pod-docker-registry-dev -it -- sh
ls /var/lib/registry/docker/registry/v2/repositories/
```

Output looks like this:

    jt1 03:00:39 ~{6} kubectl exec docker-registry-pod-docker-registry-dev -it -- sh
    / # ls /var/lib/registry/docker/registry/v2/repositories/
    mynginx

- Create a pod that uses a docker image

```bash
kubectl run nginx-pod --image=docker-registry:5000/mynginx:v1 --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "reg-cred-secret"}] } }'
```

Output looks like this:

    jt1 03:02:29 ~{7} kubectl run nginx-pod --image=docker-registry:5000/mynginx:v1 --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "reg-cred-secret"}] } }'
    pod/nginx-pod created

- Test the pod; get the IP and curl against the IPADDR:80

```bash
kubectl get pods -o wide
minikube ssh
curl 10.244.0.8:80
```

Output looks like this:

    sjcvl-jaytest1 03:07:29 ~{11} kubectl get pods -o wide
    NAME                                      READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
    docker-registry-pod-docker-registry-dev   1/1     Running   0          3h38m   10.244.0.7   minikube   <none>           <none>
    nginx-pod                                 1/1     Running   0          3m43s   10.244.0.8   minikube   <none>           <none>
    sjcvl-jaytest1 03:07:34 ~{12} minikube ssh
    Last login: Wed Mar 29 22:05:16 2023 from 192.168.49.1
    docker@minikube:~$ curl 10.244.0.8:80
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
    html { color-scheme: light dark; }
    body { width: 35em; margin: 0 auto;
    font-family: Tahoma, Verdana, Arial, sans-serif; }
    </style>
    </head>
    <body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and
    working. Further configuration is required.</p>

    <p>For online documentation and support please refer to
    <a href=http://nginx.org/>nginx.org</a>.<br/>
    Commercial support is available at
    <a href=http://nginx.com/>nginx.com</a>.</p>

    <p><em>Thank you for using nginx.</em></p>
    </body>
    </html>


