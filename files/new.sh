#!/bin/bash

working_dir=`pwd`

rm -rf cluster.csv
rm -rf mapper.csv

echo "Welcome to LoadTest Setup"
echo "-------------------------"


read -p "Do you want to run Single-Region Test (or) Multi-Region Test [S/M]: " testStatus
        if [[ $testStatus == 'S' || $testStatus == 's' ]]; then
		### User Selecting Region and Zones ###
		echo "Available Regions in US"
		echo "-----------------------"
		echo "us-central1 | us-east1 | us-east4 | us-west1 | us-west2"
		echo ""
  		read -p "Select the Region: " regionSelect
		echo ""
  		case $regionSelect in
   				us-central1)
                			echo "Available Zones in $regionSelect"
					echo "--------------------------------"
                			echo "us-central1-a | us-central1-b | us-central1-c | us-central1-f"
					echo ""
                			read -p "Select anyone Zone for the cluster: " zoneSelect
                			;;
       				us-east1)
               				echo "Available Zones in $regionSelect"
			                echo "--------------------------------"
					echo "us-east1-b | us-east1-c | us-east1-d"
					echo ""
			                read -p "Select anyone Zone for the cluster: " zoneSelect
			                ;;
			        us-east4)
			                echo "Available Zones in $regionSelect"
					echo "--------------------------------"
			                echo "us-east4-a | us-east4-b | us-east4-c"
					echo ""
			                read -p "Select anyone Zone for the cluster: " zoneSelect
			                ;;
			        us-west1)
			                echo "Available Zones in $regionSelect"
					echo "--------------------------------"
			                echo "us-west1-a | us-west1-b | us-west1-c"
					echo ""
			                read -p "Select anyone Zone for the cluster: " zoneSelect
			                ;;
				us-west2)	
			                echo "Available Zones in $regionSelect"
					echo "--------------------------------"
			                echo "us-west2-a | us-west2-b | us-west2-c"
					echo ""
			                read -p "Select anyone Zone for the cluster: " zoneSelect
			                ;;
			        *)
			                echo "You Entered Wrong Input. Please Try Again.."
			                ;;
				esac
clusterName=${regionSelect}-cluster
echo "$clusterName,$zoneSelect">cluster.csv
echo ""
###Creating Cluster in GKE with Default Values###
echo "Main Cluster is getting ready"
echo ""
gcloud container clusters create $clusterName --zone $zoneSelect --num-nodes=1 --machine-type=n1-standard-2 --image-type=ubuntu --node-labels=type=master
echo ""
gcloud container node-pools create slave --cluster $clusterName --zone $zoneSelect --machine-type=n1-standard-8 --image-type=ubuntu --node-labels=type=slave --num-nodes=1
sleep 2

echo "Complete Cluster is Ready Now..Started to deploy Pods"
echo ""
echo ""

###Connecting with the Newly Created Cluster###
echo ""
echo "Connecting to the Cluster"
gcloud container clusters get-credentials $clusterName --zone $zoneSelect --project etsyperftesting-208619
echo "Connected to the cluster"
tenant=$clusterName
echo ""

echo "Deploying Pods and Services for Loadtest"
echo "----------------------------------------"

kubectl create namespace $tenant

###Creating Slave from YAML files###
echo ""
echo ""
kubectl create -n $tenant -f $working_dir/jmeter_slaves_deploy.yaml

kubectl create -n $tenant -f $working_dir/jmeter_slaves_svc.yaml
echo "Slaves Part Created"

###Creating Master from YAML files###
echo ""
echo ""
kubectl create -n $tenant -f $working_dir/jmeter_master_configmap.yaml

kubectl create -n $tenant -f $working_dir/jmeter_master_deploy.yaml
echo "Master Part Created"
sleep 30

###Applying MountPaths in Master Pod###
master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`
kubectl exec -ti -n $tenant $master_pod -- cp  /load_test  /jmeter/load_test

kubectl exec -ti -n $tenant $master_pod -- chmod 755 /jmeter/load_test
		
echo ""
echo "Settings Applied for LoadTest"
echo ""
sleep 2
                
userOption=true
while $userOption; do

### Getting JMX and CSV Files###
echo "Upload LoadTest scripts..."
echo "--------------------------"
echo ""
	validateFile () {
		if [ -f $1 ];then
                	return 0
		else
                   echo "file not exists";
		        exit 1
		fi
		}

###JMX Files###
read -p "Enter jmx file: " jmxFile
validateFile $jmxFile
echo "Started to copy the JMX files..."

master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`
kubectl exec -it -n $tenant $master_pod -- bash -c "echo 35.227.203.198 www.etsy.com etsy.com openapi.etsy.com api.etsy.com >> /etc/hosts"
kubectl cp $jmxFile -n $tenant $master_pod:/$jmxFile
echo "JMX Copy process completed"
echo ""
echo ""

	##CSV Files##
	csvOption=true
	while $csvOption;
	do
	read -p "Do you want to pass csv file [y/n] " csvStatus
		if [[ $csvStatus == 'y' || $csvStatus == 'Y' ]];then
			echo ""
        		read -p "Does this JMX need Single or Multiple CSV files [S/M]: " csvFile
          			if [[ $csvFile == 'S' || $csvFile == 's' ]]; then
                 			read -p "Enter csv file : " csv
                 			validateFile $csv
					slave_pod=`kubectl get po -n $tenant | grep jmeter-slave | awk '{print $1}'`
					echo "Please wait for few moments.. we are copying the CSV file"
        					for i in $slave_pod
                				do
                				kubectl exec -ti -n $tenant $i -- mkdir -p /jmeter/apache-jmeter-4.0/bin/csv/
                		 		kubectl cp $csv -n $tenant $i:/jmeter/apache-jmeter-4.0/bin/csv/$csv
                				kubectl exec -it -n $tenant $i -- bash -c "echo 35.227.203.198 www.etsy.com etsy.com openapi.etsy.com api.etsy.com >> /etc/hosts"
                				done
						echo "CSV Copy Process completed"
          			elif [[ $csvFile == 'M' || $csvFile == 'm' ]]; then
			 		csvMORE=true
			 		while $csvMORE;
			        	do
					read -p "Enter csv file : " csv
                                	validateFile $csv
					echo "Please wait for few moments.. we are copying the CSV file"
                                	slave_pod=`kubectl get po -n $tenant | grep jmeter-slave | awk '{print $1}'`
                                        	for i in $slave_pod
                                        	do
                                        	kubectl exec -ti -n $tenant $i -- mkdir -p /jmeter/apache-jmeter-4.0/bin/csv/
                                        	kubectl cp $csv -n $tenant $i:/jmeter/apache-jmeter-4.0/bin/csv/$csv
                                        	kubectl exec -it -n $tenant $i -- bash -c "echo 35.227.203.198 www.etsy.com etsy.com openapi.etsy.com api.etsy.com >> /etc/hosts"
                                        	done
						echo "CSV Copy Process completed"
						read -p "Do you have another CSV [Y/n]: " multiCSV
					     		if [[ $multiCSV == 'y' || $multiCSV == 'Y' ]]; then
					        		csvMORE=true;
					    		elif [[ $multiCSV == 'n' || $multiCSV == 'N' ]]; then
                                               			csvMORE=false;
					     		else
								echo "Enter a valid response Y or N: "
								csvMORE=true;
					    		 fi
			 		done
         		 	else
           		        	echo  "Enter a valid response S or M ";
	          				csvOption=true;
          		 	fi
	csvOption=false;
		elif [[ $csvStatus == 'n'|| $csvStatus == 'N' ]];then
			csvOption=false;
		else
   			echo  "Enter a valid response y or n ";
   			csvOption=true;
		fi
	done

	###Test Ready###
	startTest=true
	while $startTest; 
	do	
	read -p "Your Test is ready.. Press Y to start and N to exit [Y/n]: " startStatus
   		if [[ $startStatus == 'y' || $startStatus == 'Y' ]]; then
 			echo "Starting the Test"
            		kubectl exec -it -n $tenant $master_pod -- /jmeter/load_test $jmxFile &
                        sleep 30
                        read -p "Do you want to stop the test [Y/n]: " abort
        	              if [[ $abort == 'y' || $abort == 'Y' ]]; then
	                    	      	kubectl -n $tenant exec -ti $master_pod -- bash /jmeter/apache-jmeter-4.0/bin/stoptest.sh
                              elif [[ $abort == 'n' || $abort == 'N' ]]; then
		 		     	startTest=false;
			      else
                          	    echo  "Wrong Response.Please wait until the test complete."
					startTest=false;
                              fi
           	elif [[ $startStatus == 'n' || $startStatus == 'N' ]]; then
	               	exit 0;
        	else
			echo  "Enter a valid response y or n: "
			startTest=true;
		fi
	startTest=false
	done

	###Option for another Test###
	sleep 10
	another=true
	while $another; 
	do
	read -p "Do You want to run another test [Y/n]: " anotherTest
		if [[ $anotherTest == 'y' || $anotherTest == 'Y' ]]; then
     			userOption;
		elif [[ $anotherTest == 'n' || $anotherTest == 'N' ]]; then
			another=false;
		else
			echo "Enter a valid response y or n: "
       	 		another=true;
		fi
	another=false;
	done

	###Deleting the Cluster###
	sleep 5
	delete=true
	while $delete; do
	read -p "Do you want to delete the cluster [y/n]: " deleteCluster
		if [[ $deleteCluster == 'y' || $deleteCluster == 'Y' ]]; then
			gcloud container clusters delete $clusterName --zone $zoneSelect --quiet
		elif [[ $deleteCluster == 'n' || $deleteCluster == 'N' ]]; then
			delete=false;
		else
     			echo  "Enter a valid response y or n ";
			delete=true;
		fi
	delete=false	
	done

###Closing the 1st while###
userOption=false
done

###1st If condition for Multi-Region Test###
	elif [[ $testStatus == 'M' || $testStatus == 'm' ]]; then
             	 echo "Multi-Region Test"
		 exit 0;
	else
   		echo  "Enter a valid response S or M:  "
	 	userOption=true;
	fi

