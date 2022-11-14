```bash
git clone https://github.com/singularityhub/singularity-hpc

```


```bash
sudo mkdir -p /opt/lmod/my-registry
sudo chmod -R 775 /opt/lmod/my-registry
sudo chown -R jay /opt/lmod/my-registry
```

```bash
shpc config add registry:/opt/lmod/my-registry

# or edit the settings file directly 

vim  ~/singularity-hpc/shpc/settings.yml


### snippet of file: 
# Registry Recipes (order of GitHub providers or paths here is honored for search path))
# To reference a path in the $PWD of the shpc install use $root_dir (e.g., $root_dir/registry)
# Please preserve the flat list format for the yaml loader
registry: [/opt/lmod/my-registry, https://github.com/jazzlyj/procedures/tree/main/jenkins/jenkins-manager]

# Registry to sync from (only to a filesystem registry supported)
sync_registry: https://github.com/singularityhub/shpc-registry
```

```bash
shpc add /home/jay/sykube/jenksmgr.sif jenkins/jenksmgr:latest
### Std out
# Registry entry jenkins/jenksmgr was added! Before shpc install, edit:
# /opt/lmod/my-registry/jenkins/jenksmgr/container.yaml
```


```bash
vim /opt/lmod/my-registry/jenkins/jenksmgr/container.yaml

#### snippet of file: 
## change this to a URL to describe your container, or to get help
url: https://github.com/jazzlyj/procedures/tree/main/jenkins/jenkins-manager

# change this to your GitHub alias (or another contact or name)
maintainer: jazzlyj
```


```bash
shpc install jenkins/jenksmgr:latest
# Module jenkins/jenksmgr:latest was created.

```