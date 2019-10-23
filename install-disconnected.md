
#set Bastion 

subscription-manager attach --pool=8a85f9815bb07800015bb084056e118a

Enable ansible repo

subscription-manager repos --disable="*"

subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.11-rpms" \
    --enable="rhel-7-server-ansible-2.6-rpms"

yum install openshift-ansible


git clone git clone https://github.com/redhat-france-sa/poc-ocp-watson.git 

ansible-playbook -i localhost, --connection=local -vv redhat-registry-mirror.yaml

/tmp/local-registry-setup-v2 

