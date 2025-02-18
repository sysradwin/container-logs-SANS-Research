#!/bin/bash
NAMESPACE="default"
MAIN_OUTPUT_DIR="./collection"
mkdir -p $MAIN_OUTPUT_DIR
OUTPUT_DIR_KUBE="$MAIN_OUTPUT_DIR/kubectl"
mkdir -p $OUTPUT_DIR_KUBE
OUTPUT_DIR_HOST="$MAIN_OUTPUT_DIR/host"
mkdir -p $OUTPUT_DIR_HOST
OUTPUT_DIR_CONF="$MAIN_OUTPUT_DIR/confluence"
mkdir -p $OUTPUT_DIR_CONF

chmod -R 666 $MAIN_OUTPUT_DIR


# Collect logs from all pods using kubectl
for pod in $(kubectl get pods -n $NAMESPACE -o name); do
    pod_name=$(echo $pod | cut -d'/' -f2)
    kubectl logs $pod -n $NAMESPACE --timestamps > "$OUTPUT_DIR_KUBE/${pod_name}.log"
done

echo "Collecting journalctl and kubectl events"
kubectl events > $OUTPUT_DIR_KUBE/kubectl-events
sudo journalctl -u kubelet > $OUTPUT_DIR_KUBE/kubelet-journal
sudo journalctl -u containerd > $OUTPUT_DIR_KUBE/containerd-journal


#Copying logs from host
echo "Copying logs from host"
sudo cp -R /var/log/* $OUTPUT_DIR_HOST
sudo cp /root/.bash_history $OUTPUT_DIR_HOST
echo -e " Collecting bash history from all users \n"
for user in $(cut -f1 -d: /etc/passwd); do cp /home/$user/.bash_history $OUTPUT_DIR_HOST/$user &> /dev/null; done


#Copying logs from Atlassian
echo "copying Atlassian opt logs (shared volume logs should be collected from worker node.)"

#Changing pod log folder permissions
kubectl exec $pod -- chmod -R 666 /opt/atlassian/confluence/logs


pod=$(kubectl get pods | grep "web" | awk '{print $1}')
kubectl cp $pod:/opt/atlassian/confluence/logs $OUTPUT_DIR_CONF
kubectl cp $pod:/tmp $OUTPUT_DIR_CONF

chmod -R 777 $MAIN_OUTPUT_DIR



tar -czf kube-and-control-logs.tar.gz $MAIN_OUTPUT_DIR
