#!/bin/bash

KOPS_VERSION='1.15.0'
# K8s recommended version for Kops: https://github.com/kubernetes/kops/blob/master/channels/stable
K8S_RECOMMENDED_VERSION="${1-1.15.5}"

KUBERNETES_ASSETS=(
  release/v${K8S_RECOMMENDED_VERSION}/
  network-plugins/
)

mirror_kubernetes_release(){
    for asset in "${KUBERNETES_ASSETS[@]}"; do
        echo $asset
        if [ ! -d ./kubernetes-release/$asset ]; then
                mkdir -p ./kubernetes-release/$asset
        fi
        echo gsutil rsync -d -r gs://kubernetes-release/$asset ./kubernetes-release/$asset
        gsutil -m rsync -d -r \
	      -x ".*s390x|.*ppc64le|.*windows|.*-arm|.*arm" \
	      gs://kubernetes-release/$asset ./kubernetes-release/$asset
    done
}

sync_release_to_s3(){
    echo "start sync_release_to_s3()"
    aws --profile=zhy s3 sync ./kubernetes-release/ s3://kops-kubernetes-release/ --acl public-read
}

mirror_kops-kubeupv2(){
    TMPDIR="/tmp/kops/$KOPS_VERSION"
    for platform in linux darwin
    do
        if [[ ! -d $TMPDIR/$platform/amd64 ]]; then
        mkdir -p $TMPDIR/$platform/amd64
        fi
        wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/$platform/amd64/kops -O $TMPDIR/$platform/amd64/kops
        wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/$platform/amd64/kops.sha1 -O $TMPDIR/$platform/amd64/kops.sha1
		wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/$platform/amd64/kops.sha256 -O $TMPDIR/$platform/amd64/kops.sha256
    done


    for file in nodeup utils.tar.gz
    do
        wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/linux/amd64/$file -O $TMPDIR/linux/amd64/$file
        wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/linux/amd64/$file.sha1 -O $TMPDIR/linux/amd64/$file.sha1
		wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/linux/amd64/$file.sha256 -O $TMPDIR/linux/amd64/$file.sha256
    done

    if [[ ! -d $TMPDIR/images ]]; then
    mkdir -p $TMPDIR/images
    fi

    p=protokube.tar.gz
    wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/images/$p -O $TMPDIR/images/$p
    wget -c https://kubeupv2.s3.amazonaws.com/kops/$KOPS_VERSION/images/$p.sha1 -O $TMPDIR/images/$p.sha1
    aws --profile zhy s3 sync $TMPDIR/ s3://kops-kubeupv2/kops/$KOPS_VERSION/ --acl public-read
}



mirror_fileRepo(){
    //在下面这行，s3://kops-file/fileRepository/kops-kubernetes-release/的kops-kubernetes-release必须和前面s3://kops-kubernetes-release/保持一致
    aws --profile zhy s3 sync s3://kops-kubernetes-release/ s3://kops-file/fileRepository/kops-kubernetes-release/ --acl public-read
    aws --profile zhy s3 sync s3://kops-kubeupv2/ s3://kops-file/fileRepository/kubeupv2/ --acl=public-read
    aws --profile zhy s3 sync s3://kops-kubeupv2/kops/$KOPS_VERSION s3://kops-file/fileRepository/kops/$KOPS_VERSION --acl public-read
	//下面这行，是因为network-plugins寻找路径问题，需要再部署一份
	aws --profile zhy s3 sync s3://kops-file/fileRepository/kops-kubernetes-release/network-plugins/ s3://kops-file/fileRepository/kubernetes-release/network-plugins/ --acl public-read
}

mirror_kubernetes_release
sync_release_to_s3
mirror_kops-kubeupv2
mirror_fileRepo
