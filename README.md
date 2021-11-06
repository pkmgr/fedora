# Fedora packages
  
To install .list file using pkmgr:  

```shell
pkmgr curl https://github.com/pkmgr/fedora/raw/main/lists/default.list
```

To install .sh script using pkmgr  

```shell
pkmgr script https://github.com/pkmgr/fedora/raw/main/scripts/default.sh
```  

use the following format to manual install:  

```shell
sudo yum install -y $(cat saved-file.txt )
```
