# Deployment in local

create a kind cluster with the one control-plane and 3 worker nodes 

```
kind create cluster --config kind-config.yaml --name hlf
```

### For Nginx
 **with the help of helm**

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

 **Create a namespace of nginx**
```
kubectl apply -f ngnix-namespace.yaml
```

**helm install the nginx**
```
helm install my-ingress -n nginx-ingress ingress-nginx/ingress-nginx   --set controller.service.type=NodePort   --set controller.service.nodePorts.http=30001   --set controller.service.nodePorts.https=30000 --create-namespace
```

### Changes for nginx 

change the type to NodePort
 
```
kubectl get svc -n nginx-ingress

kubectl edit svc <nginx-svc-name> -n nginx-ingress
```


edit the deployment and add --enable-ssl-passthrough in the args section of containers
```
kubectl get deploy -n nginx-ingress

kubectl edit deploy  <deployment-name> -n nginx-ingress
```

edit the coredns part 
```
kubectl edit configmap -n kube-system coredns
```

add the folllwing inside the corefile

```
  my-hlf-domain.com.db(dns name): |
    my-hlf-domain.com.           IN   SOA  ns3.npcinet.tech. cto.npcinet.tech. 2015032601 10800 900 1209600 86400
    ; my-hlf-domain.com file
    *.my-hlf-domain.com.         IN   A       <node-port>(k get nodes -o wide and add the INTERNAL-IP )
    *.my-hlf-domain.com.         IN   A       <node-port>
```

below prometheus we have to add below lines 

```
file /etc/coredns/my-hlf-domain.com.db my-hlf-domain.com(dns name)
```

and add the follwing key and path to the volume section

```
kubectl edit deploy coredns -n kube-system

- key: my-hlf-domain.com.db
  path: my-hlf-domain.com.db
```

restart and roll out coredns 
```
kubectl rollout restart deployment coredns -n kube-system
```

now go to the falcon  and start the process (clone the falon from the git "https://github.com/npci/falcon.git")

1. **Deploy a Filestore server.**

```
  helm install filestore -n filestore helm-charts/filestore/ -f examples/filestore/values.yaml --create-namespace
  ```

   ***IMP*** If you're changing the filestore release name/ingress port/host then you will have to update the other values file where it has a reference. 

  ```
  curl http://filestore.my-hlf-domain.com:30001
  ```

2. **Create NameSpaces For your usecase. **

```
kubectl create namespace orderer (Orderer is must for every network)
kubectl create namespace first-peer 
kubectl create namespace second-peer 
kubectl create namespace third-peer 
```

3. **Create secerts for that. **
```
kubectl -n orderer create secret generic rca-secret --from-literal=user=rca-admin --from-literal=password=rcaComplexPassword
kubectl -n orderer create secret generic orderer-secret --from-literal=user=ica-orderer --from-literal=password=icaordererSamplePassword
kubectl -n orderer create secret generic tlsca-secret --from-literal=user=tls-admin --from-literal=password=TlsComplexPassword
kubectl -n first-peer create secret generic first-peer-secret --from-literal=user=ica-first-peer --from-literal=password=icafirst-peerSamplePassword
kubectl -n second-peer create secret generic second-peer-secret --from-literal=user=ica-second-peer --from-literal=password=icasecond-peerSamplePassword
kubectl -n third-peer create secret generic third-peer-secret --from-literal=user=ica-third-peer --from-literal=password=icathird-peerSamplePassword
```


4. ** Root-CA **

```
 helm install root-ca -n orderer helm-charts/fabric-ca/ -f examples/fabric-ca/root-ca.yaml
 ```


5. **TLS-CA**
```
helm install tls-ca -n orderer helm-charts/fabric-ca/ -f examples/fabric-ca/tls-ca.yaml
```


6. **Root-ca OPS **

```
helm install rootca-ops -n orderer helm-charts/fabric-ops/ -f examples/fabric-ops/rootca/rootca-identities.yaml
```

7. **tls-ca OPS**
``` 
helm install tlsca-ops -n orderer helm-charts/fabric-ops/ -f examples/fabric-ops/tlsca/tlsca-identities.yaml 
```

8. ** ica-orderer**
```
helm install ica-orderer -n orderer helm-charts/fabric-ca/ -f examples/fabric-ca/ica-orderer.yaml
```

9. ** ica-first-peer.**
```
helm install ica-first-peer -n first-peer helm-charts/fabric-ca/ -f examples/fabric-ca/ica-first-peer.yaml --create-namespace
```

10. **orderer-ops.**
```
helm install orderer-ops -n orderer helm-charts/fabric-ops/ -f examples/fabric-ops/orderer/orderer-identities.yaml
```

11. **first-peer-ops**

```
helm install first-peer-ops -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/identities.yaml
```

12. **Cryptogen**

```
helm install cryptogen -n orderer helm-charts/fabric-ops/ -f examples/fabric-ops/orderer/orderer-cryptogen.yaml
```

13. **install orderer.**
```
helm install orderer -n orderer helm-charts/fabric-orderer/ -f examples/fabric-orderer/orderer.yaml 
```

14. **installing peer for first-peer**
```
helm install peer -n first-peer helm-charts/fabric-peer/ -f examples/fabric-peer/initialpeerorg/values.yaml
```
15. ** create channel **
```
helm install channelcreate -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/channel-create.yaml
```

16. **Copy your chaincode to the filestore.**
```
kubectl cp examples/files/basic-chaincode_go_1.0.tar.gz  filestore(filestoreNameSpace)/filestore-598978bd9c-vcs4q(filestore Pod):/usr/share/nginx/html/yourproject
```

17. **Update the anchore Peer.**
```
helm install updateanchorepeer -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/update-anchor-peer.yaml
```

18. **install the chaincode on the first-peer.**
```
 helm install installchaincode -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/install-chaincode.yaml
 ```


### Deployment Of Second-Peer

**Start with ica of the second-peer**

```
helm install ica-second-peer -n second-peer helm-charts/fabric-ca/ -f examples/fabric-ca/ica-second-peer.yaml  --create-namespace
```

configure the channel with organization first-peer is already a member of the channel so we can install this to configure our organizations with channel

```
helm install configureorgchannel -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/configure-org-channel.yaml
```

**Register the identities.**
```
 helm install second-peer-ops -n second-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org1/identities.yaml
 ```

**Install second peer.**
```
helm install peer -n second-peer helm-charts/fabric-peer/ -f examples/fabric-peer/org1/values.yaml
```

**Installing chiancode on second-peer.**
```
helm install installchaincode -n second-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org1/install-chaincode.yaml
```

**update-anchore-peer.**
```
helm install updateanchorepeer -n second-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org1/update-anchor-peer.yaml
```


### Deploy the third peer 

**Follow the same steps for the folder is in org2/.**

### Approve chaincode on all the peers

**Copying files.**

Copy the collection-config.json to filestore  with same command of copying and change the hash of collection-config.json using this command
```
sha256sum <file-name>
```

**Approve chaincode commands.**


Give owner permissions for the collection and change the sha in the approve-cahincode.yaml in all organizations.

```
helm install approvechaincode -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/approve-chaincode.yaml
helm install approvechaincode -n second-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org1/approve-chaincode.yaml 
helm install approvechaincode -n third-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org2/approve-chaincode.yaml
```

**Commit-chaincode command.**

the commit should be by the first peer 

```
helm install commitchaincode -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/commit-chaincode.yaml
```


### Upgrade the chaincode.

First we need to change the name of the chaincode in all the peer files and change the owner ship of the file to nginx

```
chown nginx:nginx basic-chaincode_go_1.0.tar.gz(file name)
```


```
 helm upgrade installchaincode -n first-peer helm-charts/fabric-ops/ -f examples/fabric-ops/initialpeerorg/install-chaincode.yaml

 helm upgrade installchaincode -n second-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org1/install-chaincode.yaml

 helm upgrade installchaincode -n third-peer helm-charts/fabric-ops/ -f examples/fabric-ops/org2/install-chaincode.yaml
 ```

copy collection-json to the filestore and change the owner ship and change the chaincode packege Id and cc_name and as well increment the the sequnace







